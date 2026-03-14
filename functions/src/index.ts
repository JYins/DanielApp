import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

interface DeleteUserData {
  uidToDelete?: string;
}

/**
 * Callable function to delete a user's Firebase Auth account and their Firestore profile.
 * Only accessible by an authenticated admin.
 */
export const deleteUserAccount = functions.https.onCall(async (data: DeleteUserData, context: functions.https.CallableContext) => {
  // 1. Verify Authentication & Authorization
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to perform this action.'
    );
  }

  const callerUid = context.auth.uid;
  
  // Verify the caller is actually an admin by checking their Firestore document
  const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
  const callerData = callerDoc.data();
  
  if (!callerDoc.exists || callerData?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only administrators can delete users.'
    );
  }

  // 2. Extract input
  const { uidToDelete } = data;
  if (!uidToDelete || typeof uidToDelete !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A valid user UID must be provided.'
    );
  }

  // Prevents an admin from accidentally deleting themselves via this specific route
  if (uidToDelete === callerUid) {
     throw new functions.https.HttpsError(
      'invalid-argument',
      'You cannot delete your own admin account through this method.'
    );
  }

  try {
    // 3. Delete from Firebase Auth
    await admin.auth().deleteUser(uidToDelete);
    console.log(`Successfully deleted auth user: ${uidToDelete}`);

    // 4. Delete from Firestore
    await admin.firestore().collection('users').doc(uidToDelete).delete();
    console.log(`Successfully deleted firestore user doc: ${uidToDelete}`);

    return { 
      success: true, 
      message: `User ${uidToDelete} completely removed.` 
    };
  } catch (error) {
    console.error('Error deleting user:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to completely delete user account.'
    );
  }
});
