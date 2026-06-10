const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

initializeApp();

const db = getFirestore();

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
