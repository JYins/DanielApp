"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteUserAdmin = exports.ping = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();
exports.ping = functions.https.onCall((_data, _context) => {
    return { status: 'ok', timestamp: new Date().toISOString() };
});
exports.deleteUserAdmin = functions
    .region('us-central1')
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'You must be logged in to perform this action.');
    }
    const callerUid = context.auth.uid;
    const callerDoc = await admin
        .firestore()
        .collection('users')
        .doc(callerUid)
        .get();
    const callerData = callerDoc.data();
    if (!callerDoc.exists || (callerData === null || callerData === void 0 ? void 0 : callerData.role) !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Only administrators can delete users.');
    }
    const { uidToDelete } = data;
    if (!uidToDelete || typeof uidToDelete !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'A valid user UID must be provided.');
    }
    if (uidToDelete === callerUid) {
        throw new functions.https.HttpsError('invalid-argument', 'You cannot delete your own admin account through this method.');
    }
    try {
        await admin.auth().deleteUser(uidToDelete);
        console.log(`Deleted auth user: ${uidToDelete}`);
    }
    catch (authErr) {
        if (authErr.code !== 'auth/user-not-found') {
            console.error('Auth deletion failed:', authErr);
            throw new functions.https.HttpsError('internal', `Failed to delete auth account: ${authErr.message}`);
        }
        console.log(`Auth user ${uidToDelete} already gone, continuing.`);
    }
    try {
        await admin.firestore().collection('users').doc(uidToDelete).delete();
        console.log(`Deleted Firestore doc: ${uidToDelete}`);
    }
    catch (fsErr) {
        console.error('Firestore deletion failed:', fsErr);
        throw new functions.https.HttpsError('internal', `Failed to delete Firestore profile: ${fsErr.message}`);
    }
    return {
        success: true,
        message: `User ${uidToDelete} completely removed.`,
    };
});
//# sourceMappingURL=index.js.map