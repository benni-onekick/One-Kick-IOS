"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewChatMessage = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
// Wird ausgelöst wenn eine neue Chat-Nachricht geschrieben wird.
// Sendet eine FCM Push-Notification an alle anderen Community-Mitglieder.
exports.onNewChatMessage = functions
    .region("europe-west1")
    .firestore.document("communities/{communityId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
    var _a, _b, _c, _d;
    const msg = snap.data();
    // Poll-Nachrichten überspringen (kein Text)
    if (msg.type === "poll")
        return null;
    const communityId = context.params.communityId;
    const senderId = msg.userId;
    const senderName = msg.displayName || "Unbekannt";
    const text = msg.text || "";
    // Community laden (Name + Mitgliederliste)
    const communityDoc = await db.collection("communities").doc(communityId).get();
    if (!communityDoc.exists)
        return null;
    const memberIds = (_b = (_a = communityDoc.data()) === null || _a === void 0 ? void 0 : _a.memberIds) !== null && _b !== void 0 ? _b : [];
    const communityName = (_d = (_c = communityDoc.data()) === null || _c === void 0 ? void 0 : _c.name) !== null && _d !== void 0 ? _d : "One Kick";
    // FCM-Tokens aller Mitglieder außer Absender laden
    const recipients = memberIds.filter((uid) => uid !== senderId);
    const tokenPromises = recipients.map((uid) => db.collection("users").doc(uid).get().then((doc) => { var _a; return (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken; }));
    const rawTokens = await Promise.all(tokenPromises);
    const tokens = rawTokens.filter((t) => !!t);
    if (tokens.length === 0)
        return null;
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
    const failedTokens = [];
    response.responses.forEach((resp, idx) => {
        var _a;
        if (!resp.success) {
            const code = (_a = resp.error) === null || _a === void 0 ? void 0 : _a.code;
            if (code === "messaging/invalid-registration-token" ||
                code === "messaging/registration-token-not-registered") {
                failedTokens.push(tokens[idx]);
            }
        }
    });
    if (failedTokens.length > 0) {
        // Ungültige Tokens aus Firestore löschen
        const cleanupPromises = recipients
            .filter((_, idx) => failedTokens.includes(tokens[idx]))
            .map((uid) => db.collection("users").doc(uid).update({ fcmToken: admin.firestore.FieldValue.delete() }));
        await Promise.all(cleanupPromises);
    }
    return null;
});
//# sourceMappingURL=index.js.map