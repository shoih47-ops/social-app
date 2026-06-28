const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldPath, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");

initializeApp();

const db = getFirestore();

const DAILY_REMINDER_MESSAGES = [
  "Hi {name}, hope you have a wonderful day. 🌿",
  "Hello {name}, today might become a memory worth keeping.",
  "Hi {name}, if something meaningful happens today, you can save or share it here.",
  "Hello {name}, every day tells a story. Don't forget to keep yours.",
  "Hi {name}, may today give you something small and beautiful to remember.",
  "Hello {name}, take a quiet moment for yourself today.",
];
const DEFAULT_REMINDER_MINUTES = 19 * 60;
const REMINDER_SEND_WINDOW_MINUTES = 20;

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
    const notificationType =
      notification.notificationType || notification.type || "";

    const fromUserId = notification.senderId || notification.fromUserId || "";
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
    const body = buildBody(notificationType, fromUsername);
    const postId = notification.postId || "";
    const postType = await getPostType(notification, postId);

    const data = stringifyData({
      postId,
      postType,
      senderId: fromUserId,
      receiverId: toUserId,
      notificationType,
      type: notificationType,
      notificationId,
      toUserId,
      fromUserId,
      fromUsername,
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

exports.sendDailyReminderNotifications = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const localTime = localTimeInfo("Asia/Kuala_Lumpur");
    const today = localTime.dateKey;
    const currentMinutes = localTime.minutesSinceMidnight;
    let checked = 0;
    let attempted = 0;
    let sent = 0;
    let skippedMissingToken = 0;
    let skippedAlreadySent = 0;
    let skippedNotDue = 0;
    let failed = 0;
    let lastDoc = null;

    logger.info("Daily reminder job started", {
      date: today,
      currentMinutes,
      schedule: "every 15 minutes",
    });

    do {
      let query = db.collection("users")
        .where("dailyRemindersEnabled", "==", true)
        .orderBy(FieldPath.documentId())
        .limit(500);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const usersSnap = await query.get();
      if (usersSnap.empty) break;

      const sendPromises = [];
      checked += usersSnap.size;

      for (const userDoc of usersSnap.docs) {
        const user = userDoc.data() || {};
        const userId = userDoc.id;
        const token = cleanText(user.fcmToken);

        if (!token) {
          skippedMissingToken += 1;
          logger.info("Skipping daily reminder: missing FCM token", {userId});
          continue;
        }

        if (user.dailyReminderLastSentDate === today) {
          skippedAlreadySent += 1;
          logger.info("Skipping daily reminder: already sent today", {
            userId,
            date: today,
          });
          continue;
        }

        const scheduledMinutes = reminderMinutes(user);
        if (!isReminderDue(currentMinutes, scheduledMinutes)) {
          skippedNotDue += 1;
          logger.info("Skipping daily reminder: selected time is not due", {
            userId,
            currentMinutes,
            scheduledMinutes,
          });
          continue;
        }

        const name = reminderName(user);
        const body = randomReminderMessage(name);

        sendPromises.push(
          sendDailyReminder({
            userId,
            token,
            body,
            today,
            scheduledMinutes,
          }),
        );
      }

      attempted += sendPromises.length;
      const results = await Promise.all(sendPromises);
      for (const result of results) {
        if (result.sent) {
          sent += 1;
        } else {
          failed += 1;
        }
      }
      lastDoc = usersSnap.docs[usersSnap.docs.length - 1];
    } while (lastDoc);

    logger.info("Daily reminders processed", {
      date: today,
      checked,
      attempted,
      sent,
      skippedMissingToken,
      skippedAlreadySent,
      skippedNotDue,
      failed,
    });
  },
);

async function sendDailyReminder({
  userId,
  token,
  body,
  today,
  scheduledMinutes,
}) {
  try {
    const messageId = await getMessaging().send({
      token,
      notification: {
        title: "Journa",
        body,
      },
      data: stringifyData({
        notificationType: "dailyReminder",
        type: "dailyReminder",
        receiverId: userId,
        toUserId: userId,
      }),
      android: {
        priority: "normal",
        notification: {
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    await db.collection("users").doc(userId).set({
      dailyReminderLastSentDate: today,
      dailyReminderLastSentAt: FieldValue.serverTimestamp(),
      dailyReminderLastSentScheduledMinutes: scheduledMinutes,
    }, {merge: true});

    logger.info("Daily reminder sent", {
      userId,
      date: today,
      scheduledMinutes,
      messageId,
    });

    return {sent: true};
  } catch (error) {
    logger.error("Failed to send daily reminder", {
      userId,
      code: error.code,
      message: error.message,
    });

    if (isInvalidTokenError(error)) {
      await db.collection("users").doc(userId).set({
        fcmToken: FieldValue.delete(),
        fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    return {sent: false};
  }
}

async function getFromUsername(notification, fromUserId) {
  if (notification.fromUsername) return notification.fromUsername;
  if (!fromUserId) return "Someone";

  const fromUserSnap = await db.collection("users").doc(fromUserId).get();
  return fromUserSnap.get("username") || "Someone";
}

async function getPostType(notification, postId) {
  if (notification.postType) return String(notification.postType);
  if (!postId) return "";

  const postSnap = await db.collection("posts").doc(postId).get();
  return postSnap.exists ? String(postSnap.get("type") || "") : "";
}

function reminderName(user) {
  return cleanText(user.displayName) ||
    cleanText(user.name) ||
    cleanText(user.username) ||
    "there";
}

function reminderMinutes(user) {
  const value = Number(user.dailyReminderTimeMinutes);
  if (Number.isInteger(value) && value >= 0 && value < 24 * 60) {
    return value;
  }
  return DEFAULT_REMINDER_MINUTES;
}

function isReminderDue(currentMinutes, scheduledMinutes) {
  const elapsed = currentMinutes - scheduledMinutes;
  return elapsed >= 0 && elapsed <= REMINDER_SEND_WINDOW_MINUTES;
}

function randomReminderMessage(name) {
  const template = DAILY_REMINDER_MESSAGES[
    Math.floor(Math.random() * DAILY_REMINDER_MESSAGES.length)
  ];
  return template.replace("{name}", name);
}

function localDateKey(timeZone) {
  return localTimeInfo(timeZone).dateKey;
}

function localTimeInfo(timeZone) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    hourCycle: "h23",
  }).formatToParts(new Date());

  const values = Object.fromEntries(
    parts
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );

  return {
    dateKey: `${values.year}-${values.month}-${values.day}`,
    minutesSinceMidnight: Number(values.hour) * 60 + Number(values.minute),
  };
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
    case "tagged":
      return `${fromUsername} tagged you in a moment.`;
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
