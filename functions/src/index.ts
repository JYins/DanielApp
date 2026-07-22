import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue } from '@google-cloud/firestore';

admin.initializeApp();

type AccessRole = 'admin' | 'global_admin' | 'region_admin' | 'branch_admin' | 'member';
type MembershipStatus = 'active' | 'pending' | 'requested' | 'revoked';

type AdminScope = {
  uid: string;
  accessRole: AccessRole;
  orgId: string;
  regionId: string;
  branchId: string;
};

const accessRoles: AccessRole[] = [
  'admin',
  'global_admin',
  'region_admin',
  'branch_admin',
  'member',
];

const membershipStatuses: MembershipStatus[] = [
  'active',
  'pending',
  'requested',
  'revoked',
];

async function assertGlobalAdmin(
  context: functions.https.CallableContext
): Promise<string> {
  const caller = await loadAdminScope(context);
  if (!isGlobalAdmin(caller.accessRole)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only global administrators can perform this action.'
    );
  }

  return caller.uid;
}

async function loadAdminScope(
  context: functions.https.CallableContext
): Promise<AdminScope> {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to perform this action.'
    );
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin
    .firestore()
    .collection('users')
    .doc(callerUid)
    .get();
  const callerData = callerDoc.data();
  const accessRole = normalizedAccessRole(
    callerData?.accessRole || callerData?.role,
    'member'
  );
  const membershipStatus = normalizedMembershipStatus(
    callerData?.membershipStatus,
    callerData?.isApproved === true ? 'active' : 'pending'
  );

  if (
    !callerDoc.exists ||
    callerData?.isApproved !== true ||
    !['active', 'approved'].includes(membershipStatus) ||
    !['admin', 'global_admin', 'region_admin', 'branch_admin'].includes(accessRole)
  ) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only approved administrators can perform this action.'
    );
  }

  return {
    uid: callerUid,
    accessRole,
    orgId: String(callerData?.orgId || 'daniel-branch-church'),
    regionId: String(callerData?.regionId || ''),
    branchId: String(callerData?.branchId || ''),
  };
}

function normalizedAccessRole(value: unknown, fallback: AccessRole): AccessRole {
  if (typeof value === 'string' && accessRoles.includes(value as AccessRole)) {
    return value as AccessRole;
  }
  return fallback;
}

function normalizedMembershipStatus(
  value: unknown,
  fallback: MembershipStatus
): MembershipStatus {
  if (
    typeof value === 'string' &&
    membershipStatuses.includes(value as MembershipStatus)
  ) {
    return value as MembershipStatus;
  }
  return fallback;
}

function legacyRoleFor(accessRole: AccessRole): AccessRole {
  return accessRole === 'global_admin' ? 'admin' : accessRole;
}

function isGlobalAdmin(accessRole: AccessRole): boolean {
  return accessRole === 'admin' || accessRole === 'global_admin';
}

function targetCurrentRole(userData: FirebaseFirestore.DocumentData): AccessRole {
  return normalizedAccessRole(userData.accessRole || userData.role, 'member');
}

function assertCanSetUserAccess(params: {
  caller: AdminScope;
  targetUid: string;
  targetData: FirebaseFirestore.DocumentData;
  branchId: string;
  branchData?: FirebaseFirestore.DocumentData;
  accessRole: AccessRole;
}): void {
  const {
    caller,
    targetUid,
    targetData,
    branchId,
    branchData,
    accessRole,
  } = params;

  if (isGlobalAdmin(caller.accessRole)) {
    return;
  }

  if (targetUid === caller.uid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Scoped administrators cannot change their own access.'
    );
  }

  const currentRole = targetCurrentRole(targetData);
  if (['admin', 'global_admin', 'region_admin'].includes(currentRole)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Scoped administrators cannot manage global or regional administrators.'
    );
  }

  if (!branchId || !branchData) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Scoped administrator updates must include a valid branch.'
    );
  }

  const branchRegionId = String(branchData.regionId || '');
  const currentRegionId = String(targetData.regionId || '');
  const currentBranchId = String(targetData.branchId || '');

  if (caller.accessRole === 'region_admin') {
    if (!caller.regionId || branchRegionId !== caller.regionId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Region administrators can only manage users inside their region.'
      );
    }

    if (currentRegionId && currentRegionId !== caller.regionId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Region administrators cannot move users from another region.'
      );
    }

    if (!['member', 'branch_admin'].includes(accessRole)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Region administrators can only assign member or branch admin roles.'
      );
    }

    return;
  }

  if (caller.accessRole === 'branch_admin') {
    if (!caller.branchId || branchId !== caller.branchId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Branch administrators can only manage users inside their branch.'
      );
    }

    if (currentBranchId && currentBranchId !== caller.branchId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Branch administrators cannot move users from another branch.'
      );
    }

    if (currentRole !== 'member' || accessRole !== 'member') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Branch administrators can only approve or revoke member access.'
      );
    }

    return;
  }

  throw new functions.https.HttpsError(
    'permission-denied',
    'Your administrator role cannot perform this action.'
  );
}

function membershipId(branchId: string, uid: string): string {
  return `${branchId}_${uid}`;
}

function localizedText(value: unknown, fallback: string): string {
  if (typeof value === 'string' && value.trim()) {
    return value.trim();
  }

  if (value && typeof value === 'object') {
    const map = value as Record<string, unknown>;
    for (const key of ['en', 'zh', 'ko']) {
      const localizedValue = map[key];
      if (typeof localizedValue === 'string' && localizedValue.trim()) {
        return localizedValue.trim();
      }
    }
  }

  return fallback;
}

export const ping = functions.https.onCall(
  (_data: unknown, _context: functions.https.CallableContext) => {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
);

export const deleteUserAdmin = functions
  .region('us-central1')
  .https.onCall(
    async (
      data: { uidToDelete?: string },
      context: functions.https.CallableContext
    ) => {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'You must be logged in to perform this action.');
      }

      const callerUid = await assertGlobalAdmin(context);

      const { uidToDelete } = data;
      if (!uidToDelete || typeof uidToDelete !== 'string') {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'A valid user UID must be provided.'
        );
      }

      if (uidToDelete === callerUid) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'You cannot delete your own admin account through this method.'
        );
      }

      try {
        await admin.auth().deleteUser(uidToDelete);
        console.log(`Deleted auth user: ${uidToDelete}`);
      } catch (authErr: any) {
        if (authErr.code !== 'auth/user-not-found') {
          console.error('Auth deletion failed:', authErr);
          throw new functions.https.HttpsError(
            'internal',
            `Failed to delete auth account: ${authErr.message}`
          );
        }
        console.log(`Auth user ${uidToDelete} already gone, continuing.`);
      }

      try {
        await admin.firestore().collection('users').doc(uidToDelete).delete();
        console.log(`Deleted Firestore doc: ${uidToDelete}`);

        const memberships = await admin
          .firestore()
          .collection('branchMemberships')
          .where('userId', '==', uidToDelete)
          .get();
        const batch = admin.firestore().batch();
        memberships.docs.forEach((membershipDoc) => {
          batch.delete(membershipDoc.ref);
        });
        await batch.commit();
        console.log(`Deleted ${memberships.size} membership docs for: ${uidToDelete}`);
      } catch (fsErr: any) {
        console.error('Firestore deletion failed:', fsErr);
        throw new functions.https.HttpsError(
          'internal',
          `Failed to delete Firestore profile: ${fsErr.message}`
        );
      }

      return {
        success: true,
        message: `User ${uidToDelete} completely removed.`,
      };
    }
  );

export const setUserAccessAdmin = functions
  .region('us-central1')
  .https.onCall(
    async (
      data: {
        uid?: unknown;
        isApproved?: unknown;
        branchId?: unknown;
        accessRole?: unknown;
        membershipStatus?: unknown;
      },
      context: functions.https.CallableContext
    ) => {
      const caller = await loadAdminScope(context);

      const uid = typeof data.uid === 'string' ? data.uid.trim() : '';
      if (!uid) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'A valid user UID must be provided.'
        );
      }

      const db = admin.firestore();
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          `User profile ${uid} does not exist.`
        );
      }

      const userData = userDoc.data() || {};
      const currentAccessRole = normalizedAccessRole(
        userData.accessRole || userData.role,
        'member'
      );
      const accessRole = normalizedAccessRole(data.accessRole, currentAccessRole);
      const role = legacyRoleFor(accessRole);
      const isApproved =
        typeof data.isApproved === 'boolean' ? data.isApproved : userData.isApproved === true;
      const currentMembershipStatus = normalizedMembershipStatus(
        userData.membershipStatus,
        isApproved ? 'active' : 'pending'
      );
      const membershipStatus = normalizedMembershipStatus(
        data.membershipStatus,
        isApproved ? 'active' : currentMembershipStatus
      );

      if (
        uid === caller.uid &&
        (!isApproved || !['admin', 'global_admin'].includes(accessRole))
      ) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'You cannot revoke or demote your own global admin account.'
        );
      }

      const branchId =
        typeof data.branchId === 'string' && data.branchId.trim()
          ? data.branchId.trim()
          : typeof userData.branchId === 'string'
            ? userData.branchId
            : '';

      let branchData: FirebaseFirestore.DocumentData | undefined;
      if (branchId) {
        const branchDoc = await db.collection('branches').doc(branchId).get();
        if (!branchDoc.exists) {
          throw new functions.https.HttpsError(
            'not-found',
            `Branch ${branchId} does not exist.`
          );
        }
        branchData = branchDoc.data();
      }

      assertCanSetUserAccess({
        caller,
        targetUid: uid,
        targetData: userData,
        branchId,
        branchData,
        accessRole,
      });

      const now = FieldValue.serverTimestamp();
      const branchName = branchData
        ? localizedText(branchData.name, branchId)
        : localizedText(userData.branchName, branchId);
      const regionName = branchData
        ? localizedText(branchData.regionName, String(branchData.regionId || ''))
        : localizedText(userData.regionName, String(userData.regionId || ''));
      const orgId = String(branchData?.orgId || userData.orgId || 'daniel-branch-church');
      const regionId = String(branchData?.regionId || userData.regionId || '');
      const country = String(branchData?.country || userData.churchCountry || regionName);

      const userUpdate: Record<string, unknown> = {
        isApproved,
        approvedAt: isApproved ? now : null,
        approvedBy: isApproved ? caller.uid : null,
        role,
        accessRole,
        membershipStatus,
        orgId,
        regionId,
        regionName,
        branchId,
        branchName,
        churchCountry: country,
        churchName: branchName,
        updatedAt: now,
      };

      const batch = db.batch();
      batch.update(userRef, userUpdate);

      const oldBranchId = typeof userData.branchId === 'string' ? userData.branchId : '';
      if (oldBranchId && oldBranchId !== branchId) {
        batch.set(
          db.collection('branchMemberships').doc(membershipId(oldBranchId, uid)),
          {
            id: membershipId(oldBranchId, uid),
            userId: uid,
            orgId: userData.orgId || orgId,
            regionId: userData.regionId || regionId,
            branchId: oldBranchId,
            role: userData.role || 'member',
            accessRole: userData.accessRole || userData.role || 'member',
            status: 'revoked',
            updatedAt: now,
          },
          { merge: true }
        );
      }

      if (branchId) {
        batch.set(
          db.collection('branchMemberships').doc(membershipId(branchId, uid)),
          {
            id: membershipId(branchId, uid),
            userId: uid,
            orgId,
            regionId,
            branchId,
            role,
            accessRole,
            status: membershipStatus,
            createdAt: now,
            updatedAt: now,
            approvedAt: isApproved ? now : null,
            approvedBy: isApproved ? caller.uid : null,
          },
          { merge: true }
        );
      }

      await batch.commit();

      try {
        await admin.auth().setCustomUserClaims(uid, {
          accessRole,
          role,
          isApproved,
          membershipStatus,
          orgId,
          regionId,
          branchId,
        });
      } catch (authErr: any) {
        if (authErr.code !== 'auth/user-not-found') {
          throw authErr;
        }
      }

      return {
        success: true,
        uid,
        accessRole,
        role,
        isApproved,
        membershipStatus,
        orgId,
        regionId,
        branchId,
      };
    }
  );
