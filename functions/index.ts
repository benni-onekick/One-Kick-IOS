import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// Wird ausgelöst wenn eine neue Chat-Nachricht geschrieben wird.
// Sendet eine FCM Push-Notification an alle anderen Community-Mitglieder.
export const onNewChatMessage = functions
  .region("europe-west1")
  .firestore.document("communities/{communityId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const msg = snap.data();

    // Poll-Nachrichten überspringen (kein Text)
    if (msg.type === "poll") return null;

    const communityId = context.params.communityId;
    const senderId = msg.userId as string;
    const senderName = (msg.displayName as string) || "Unbekannt";
    const text = (msg.text as string) || "";

    // Community laden (Name + Mitgliederliste)
    const communityDoc = await db.collection("communities").doc(communityId).get();
    if (!communityDoc.exists) return null;

    const memberIds: string[] = communityDoc.data()?.memberIds ?? [];
    const communityName: string = communityDoc.data()?.name ?? "One Kick";

    // FCM-Tokens aller Mitglieder außer Absender laden
    const recipients = memberIds.filter((uid) => uid !== senderId);
    const tokenPromises = recipients.map((uid) =>
      db.collection("users").doc(uid).get().then((doc) => doc.data()?.fcmToken as string | undefined)
    );
    const rawTokens = await Promise.all(tokenPromises);
    const tokens = rawTokens.filter((t): t is string => !!t);

    if (tokens.length === 0) return null;

    const body = text.length > 100 ? text.substring(0, 97) + "…" : text;

    // FCM Multicast senden
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `${communityName} · ${senderName}`,
        body,
      },
      data: { communityId },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
      android: {
        notification: { sound: "default" },
      },
    });

    // Ungültige Tokens aufräumen
    const failedTokens: string[] = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const code = resp.error?.code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          failedTokens.push(tokens[idx]);
        }
      }
    });

    if (failedTokens.length > 0) {
      // Ungültige Tokens aus Firestore löschen
      const cleanupPromises = recipients
        .filter((_, idx) => failedTokens.includes(tokens[idx]))
        .map((uid) =>
          db.collection("users").doc(uid).update({ fcmToken: admin.firestore.FieldValue.delete() })
        );
      await Promise.all(cleanupPromises);
    }

    return null;
  });
