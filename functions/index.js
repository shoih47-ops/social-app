const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");

initializeApp();

const db = getFirestore();

exports.postPreview = onRequest(async (req, res) => {
  const postId = postIdFromRequest(req.path);
  if (!postId) {
    res.status(404).send("Post not found");
    return;
  }

  try {
    const postSnap = await db.collection("posts").doc(postId).get();
    if (!postSnap.exists) {
      res.status(404).send("Post not found");
      return;
    }

    const post = postSnap.data() || {};
    const origin = requestOrigin(req);
    const postUrl = `${origin}/post/${encodeURIComponent(postId)}`;
    const appUrl = `${origin}/#/post/${encodeURIComponent(postId)}`;
    const username = await postUsername(post);
    const text = cleanText(post.text);
    const title = truncate(username, 90);
    const description = truncate(
      text || `${username} shared a real life moment on Journa`,
      220,
    );
    const postImageUrl = cleanText(post.imageUrl);
    const imageUrl = absoluteUrl(origin, postImageUrl || "/icons/Icon-512.png");
    const type = post.type === "video" ? "video.other" : "article";

    res.set("Cache-Control", "public, max-age=300, s-maxage=600");
    res.status(200).send(postPreviewHtml({
      title,
      description,
      imageUrl,
      postUrl,
      appUrl,
      type,
    }));
  } catch (error) {
    logger.error("Failed to render post preview", {postId, error});
    res.status(500).send("Could not load post preview");
  }
});

exports.sendPushForNotification = onDocumentCreated(
  "notifications/{userId}/items/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const toUserId = event.params.userId;
    const notificationId = event.params.notificationId;
    const notification = snap.data() || {};

    const fromUserId = notification.fromUserId || "";
    if (fromUserId && fromUserId === toUserId) return;

    const userSnap = await db.collection("users").doc(toUserId).get();
    const token = userSnap.get("fcmToken");

    if (!token) {
      logger.info("No FCM token for notification target", {
        toUserId,
        notificationId,
      });
      return;
    }

    const fromUsername = await getFromUsername(notification, fromUserId);
    const body = buildBody(notification.type, fromUsername);

    const data = stringifyData({
      type: notification.type,
      notificationId,
      toUserId,
      fromUserId,
      fromUsername,
      postId: notification.postId,
      commentId: notification.commentId,
      replyId: notification.replyId,
    });

    try {
      await getMessaging().send({
        token,
        notification: {
          title: "Social App",
          body,
        },
        data,
        android: {
          priority: "high",
          notification: {
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      });
    } catch (error) {
      logger.error("Failed to send push notification", {
        toUserId,
        notificationId,
        code: error.code,
        message: error.message,
      });

      if (isInvalidTokenError(error)) {
        await db.collection("users").doc(toUserId).set({
          fcmToken: FieldValue.delete(),
          fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }
  },
);

async function getFromUsername(notification, fromUserId) {
  if (notification.fromUsername) return notification.fromUsername;
  if (!fromUserId) return "Someone";

  const fromUserSnap = await db.collection("users").doc(fromUserId).get();
  return fromUserSnap.get("username") || "Someone";
}

async function postUsername(post) {
  const postName = cleanText(post.username);
  if (postName) return postName;

  const userId = cleanText(post.userId);
  if (!userId) return "Journa";

  const userSnap = await db.collection("users").doc(userId).get();
  return cleanText(userSnap.get("username")) || "Journa";
}

function buildBody(type, fromUsername) {
  switch (type) {
    case "like":
      return `${fromUsername} liked your post`;
    case "comment":
      return `${fromUsername} commented on your post`;
    case "follow":
      return `${fromUsername} started following you`;
    case "reply":
      return `${fromUsername} replied to your comment`;
    default:
      return `${fromUsername} sent you a notification`;
  }
}

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [key, String(value)]),
  );
}

function isInvalidTokenError(error) {
  return [
    "messaging/invalid-registration-token",
    "messaging/registration-token-not-registered",
  ].includes(error.code);
}

function postIdFromRequest(path) {
  const segments = String(path || "")
    .split("/")
    .map((segment) => segment.trim())
    .filter(Boolean);

  if (segments[0] === "post" && segments[1]) return segments[1];
  if (segments[0]) return segments[0];
  return "";
}

function requestOrigin(req) {
  const protocol = req.get("x-forwarded-proto") || req.protocol || "https";
  const host = req.get("x-forwarded-host") || req.get("host");
  return `${protocol}://${host}`;
}

function cleanText(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function truncate(value, maxLength) {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, maxLength - 3).trim()}...`;
}

function absoluteUrl(origin, value) {
  if (/^https?:\/\//i.test(value)) return value;
  return `${origin}${value.startsWith("/") ? "" : "/"}${value}`;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function postPreviewHtml({title, description, imageUrl, postUrl, appUrl, type}) {
  const safeTitle = escapeHtml(title);
  const safeDescription = escapeHtml(description);
  const safeImageUrl = escapeHtml(imageUrl);
  const safePostUrl = escapeHtml(postUrl);
  const safeAppUrl = escapeHtml(appUrl);
  const jsonAppUrl = JSON.stringify(appUrl);
  const imageType = escapeHtml(imageMimeType(imageUrl));

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${safeTitle}</title>
  <meta name="description" content="${safeDescription}">
  <link rel="canonical" href="${safePostUrl}">
  <meta property="og:site_name" content="Journa">
  <meta property="og:type" content="${escapeHtml(type)}">
  <meta property="og:title" content="${safeTitle}">
  <meta property="og:description" content="${safeDescription}">
  <meta property="og:image" content="${safeImageUrl}">
  <meta property="og:image:secure_url" content="${safeImageUrl}">
  <meta property="og:image:type" content="${imageType}">
  <meta property="og:url" content="${safePostUrl}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${safeTitle}">
  <meta name="twitter:description" content="${safeDescription}">
  <meta name="twitter:image" content="${safeImageUrl}">
</head>
<body>
  <main>
    <h1>${safeTitle}</h1>
    <p>${safeDescription}</p>
    <p><a href="${safeAppUrl}">Open this post in Journa</a></p>
  </main>
  <script>
    const isCrawler = /bot|crawler|spider|facebookexternalhit|Facebot|WhatsApp|TelegramBot|Twitterbot|LinkedInBot|Slackbot/i.test(navigator.userAgent);
    if (!isCrawler) {
      window.location.replace(${jsonAppUrl});
    }
  </script>
</body>
</html>`;
}

function imageMimeType(imageUrl) {
  const path = imageUrl.split("?")[0].toLowerCase();
  if (path.endsWith(".png")) return "image/png";
  if (path.endsWith(".webp")) return "image/webp";
  if (path.endsWith(".gif")) return "image/gif";
  return "image/jpeg";
}
