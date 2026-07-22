#!/usr/bin/env node

const fs = require("fs");
const { execFileSync } = require("child_process");
const admin = require("../functions/node_modules/firebase-admin");

function defaultProjectId() {
  if (!fs.existsSync("GoogleService-Info.plist")) {
    return "danielapp-dev";
  }

  try {
    const projectId = execFileSync(
      "/usr/libexec/PlistBuddy",
      ["-c", "Print :PROJECT_ID", "GoogleService-Info.plist"],
      { encoding: "utf8" }
    ).trim();
    return projectId || "danielapp-dev";
  } catch {
    return "danielapp-dev";
  }
}

const projectId = process.env.GCLOUD_PROJECT || defaultProjectId();

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error("Refusing to seed: FIRESTORE_EMULATOR_HOST is not set.");
  process.exit(1);
}

if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error("Refusing to seed: FIREBASE_AUTH_EMULATOR_HOST is not set.");
  process.exit(1);
}

admin.initializeApp({ projectId });

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const users = [
  {
    uid: "test-unassigned-user",
    email: "unassigned@example.test",
    password: "password123",
    profile: {
      userId: "test-unassigned-user",
      email: "unassigned@example.test",
      name: "Unassigned Test Member",
      isApproved: false,
      role: "member",
      accessRole: "member",
      membershipStatus: "unassigned",
      orgId: "daniel-branch-church",
      regionId: "",
      regionName: "",
      branchId: "",
      branchName: "",
      churchName: "",
      churchCountry: "",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      lastLoginDate: FieldValue.serverTimestamp()
    }
  },
  {
    uid: "test-approved-user",
    email: "approved@example.test",
    password: "password123",
    profile: {
      userId: "test-approved-user",
      email: "approved@example.test",
      name: "Approved Test Member",
      isApproved: true,
      role: "member",
      accessRole: "member",
      membershipStatus: "active",
      orgId: "daniel-branch-church",
      regionId: "canada",
      regionName: "Canada",
      branchId: "canada-daniel-test-church",
      branchName: "Daniel Test Church",
      churchName: "Daniel Test Church",
      churchCountry: "CA",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      lastLoginDate: FieldValue.serverTimestamp()
    }
  },
  {
    uid: "test-other-user",
    email: "other@example.test",
    password: "password123",
    profile: {
      userId: "test-other-user",
      email: "other@example.test",
      name: "Other Test Member",
      isApproved: true,
      role: "member",
      accessRole: "member",
      membershipStatus: "active",
      orgId: "daniel-branch-church",
      regionId: "canada",
      regionName: "Canada",
      branchId: "canada-other-test-church",
      branchName: "Other Test Church",
      churchName: "Daniel Test Church",
      churchCountry: "CA",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }
  },
  {
    uid: "test-admin-user",
    email: "admin@example.test",
    password: "password123",
    profile: {
      userId: "test-admin-user",
      email: "admin@example.test",
      name: "Admin Test Member",
      isApproved: true,
      role: "admin",
      accessRole: "global_admin",
      membershipStatus: "active",
      orgId: "daniel-branch-church",
      regionId: "canada",
      regionName: "Canada",
      branchId: "canada-daniel-test-church",
      branchName: "Daniel Test Church",
      churchName: "Daniel Test Church",
      churchCountry: "CA",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }
  },
  {
    uid: "test-region-admin-user",
    email: "region-admin@example.test",
    password: "password123",
    profile: {
      userId: "test-region-admin-user",
      email: "region-admin@example.test",
      name: "Region Admin Test Member",
      isApproved: true,
      role: "region_admin",
      accessRole: "region_admin",
      membershipStatus: "active",
      orgId: "daniel-branch-church",
      regionId: "canada",
      regionName: "Canada",
      branchId: "canada-daniel-test-church",
      branchName: "Daniel Test Church",
      churchName: "Daniel Test Church",
      churchCountry: "CA",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }
  },
  {
    uid: "test-branch-admin-user",
    email: "branch-admin@example.test",
    password: "password123",
    profile: {
      userId: "test-branch-admin-user",
      email: "branch-admin@example.test",
      name: "Branch Admin Test Member",
      isApproved: true,
      role: "branch_admin",
      accessRole: "branch_admin",
      membershipStatus: "active",
      orgId: "daniel-branch-church",
      regionId: "canada",
      regionName: "Canada",
      branchId: "canada-daniel-test-church",
      branchName: "Daniel Test Church",
      churchName: "Daniel Test Church",
      churchCountry: "CA",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }
  },
  {
    uid: "test-pending-branch-user",
    email: "pending-branch@example.test",
    password: "password123",
    profile: {
      userId: "test-pending-branch-user",
      email: "pending-branch@example.test",
      name: "Pending Branch Test Member",
      isApproved: false,
      role: "member",
      accessRole: "member",
      membershipStatus: "pending",
      orgId: "daniel-branch-church",
      regionId: "canada",
      regionName: "Canada",
      branchId: "canada-daniel-test-church",
      branchName: "Daniel Test Church",
      churchName: "Daniel Test Church",
      churchCountry: "CA",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }
  },
  {
    uid: "test-outside-region-user",
    email: "outside-region@example.test",
    password: "password123",
    profile: {
      userId: "test-outside-region-user",
      email: "outside-region@example.test",
      name: "Outside Region Test Member",
      isApproved: true,
      role: "member",
      accessRole: "member",
      membershipStatus: "active",
      orgId: "daniel-branch-church",
      regionId: "korea",
      regionName: "Korea",
      branchId: "korea-seoul-test-church",
      branchName: "Seoul Test Church",
      churchName: "Seoul Test Church",
      churchCountry: "KR",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }
  }
];

async function upsertAuthUser(user) {
  try {
    await admin.auth().deleteUser(user.uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      throw error;
    }
  }

  await admin.auth().createUser({
    uid: user.uid,
    email: user.email,
    password: user.password,
    emailVerified: true
  });

  await admin.auth().setCustomUserClaims(user.uid, {
    role: user.profile.role,
    accessRole: user.profile.accessRole,
    orgId: user.profile.orgId,
    regionId: user.profile.regionId,
    branchId: user.profile.branchId,
    membershipStatus: user.profile.membershipStatus,
    isApproved: user.profile.isApproved
  });
}

async function clearCollection(collectionName) {
  const snapshot = await db.collection(collectionName).get();
  if (snapshot.empty) {
    return;
  }
  const batch = db.batch();
  snapshot.docs.forEach((document) => batch.delete(document.ref));
  await batch.commit();
}

async function seed() {
  await clearCollection("branchInvites");
  await clearCollection("inviteRedemptions");

  for (const user of users) {
    await upsertAuthUser(user);
    await db.collection("users").doc(user.uid).set(user.profile, { merge: true });
  }

  const localized = (value) => ({ zh: value, en: value, ko: value });

  await db.collection("organizations").doc("daniel-branch-church").set({
    id: "daniel-branch-church",
    name: {
      zh: "Daniel 分堂教会",
      en: "Daniel Branch Church",
      ko: "Daniel 지교회"
    },
    isActive: true,
    sortOrder: 10,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  const regions = [
    { id: "canada", name: "Canada", country: "CA", sortOrder: 10 },
    { id: "korea", name: "Korea", country: "KR", sortOrder: 20 }
  ];

  for (const region of regions) {
    await db.collection("regions").doc(region.id).set({
      id: region.id,
      orgId: "daniel-branch-church",
      code: region.id,
      name: localized(region.name),
      country: region.country,
      isActive: true,
      sortOrder: region.sortOrder,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });
  }

  const branches = [
    {
      id: "canada-daniel-test-church",
      regionId: "canada",
      regionName: "Canada",
      name: "Daniel Test Church",
      country: "CA",
      city: "Toronto",
      timezone: "America/Toronto",
      sortOrder: 10
    },
    {
      id: "canada-other-test-church",
      regionId: "canada",
      regionName: "Canada",
      name: "Other Test Church",
      country: "CA",
      city: "Vancouver",
      timezone: "America/Vancouver",
      sortOrder: 20
    },
    {
      id: "korea-seoul-test-church",
      regionId: "korea",
      regionName: "Korea",
      name: "Seoul Test Church",
      country: "KR",
      city: "Seoul",
      timezone: "Asia/Seoul",
      sortOrder: 30
    }
  ];

  for (const branch of branches) {
    await db.collection("branches").doc(branch.id).set({
      id: branch.id,
      orgId: "daniel-branch-church",
      regionId: branch.regionId,
      regionName: localized(branch.regionName),
      code: branch.id,
      name: localized(branch.name),
      country: branch.country,
      city: branch.city,
      timezone: branch.timezone,
      isActive: true,
      sortOrder: branch.sortOrder,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });
  }

  for (const user of users) {
    const profile = user.profile;
    if (!profile.branchId) {
      continue;
    }
    await db.collection("branchMemberships").doc(`${profile.branchId}_${user.uid}`).set({
      id: `${profile.branchId}_${user.uid}`,
      userId: user.uid,
      orgId: profile.orgId,
      regionId: profile.regionId,
      branchId: profile.branchId,
      role: profile.role,
      accessRole: profile.accessRole,
      status: profile.membershipStatus,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });
  }

  await db.collection("users")
    .doc("test-approved-user")
    .collection("verseEngagement")
    .doc("John 3:16")
    .set({
      reference: "John 3:16",
      isRead: true,
      isFavorite: true,
      isLiked: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });

  await db.collection("newsletters").doc("test-weekly-newsletter").set({
    branchId: "canada-daniel-test-church",
    contentType: "newsletter",
    publishDate: FieldValue.serverTimestamp(),
    image_urls: ["https://example.test/newsletter.jpg"],
    caption_cn: "本周教会通讯测试资料",
    caption_en: "Weekly newsletter test seed",
    caption_kr: "주간 소식 테스트 자료",
    published: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  await db.collection("newsletters").doc("test-other-branch-newsletter").set({
    branchId: "canada-other-test-church",
    contentType: "newsletter",
    publishDate: FieldValue.serverTimestamp(),
    image_urls: ["https://example.test/other-newsletter.jpg"],
    caption_cn: "其他教会通讯测试资料",
    caption_en: "Other branch newsletter test seed",
    caption_kr: "다른 교회 소식 테스트 자료",
    published: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  await db.collection("announcements").doc("test-sunday-announcement").set({
    branchId: "canada-daniel-test-church",
    contentType: "announcement",
    title: localized("Sunday Service"),
    body: localized("Service begins at 10:30 AM."),
    published: true,
    publishDate: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  await db.collection("branchConnect").doc("canada-daniel-test-church").set({
    branchId: "canada-daniel-test-church",
    groupNameZh: "Daniel 测试教会 KakaoTalk",
    groupNameEn: "Daniel Test Church KakaoTalk",
    groupNameKo: "다니엘 테스트 교회 카카오톡",
    kakaoURL: "https://open.kakao.com/o/example-test",
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  await db.collection("branchConnect").doc("canada-other-test-church").set({
    branchId: "canada-other-test-church",
    groupNameZh: "其他测试教会 KakaoTalk",
    groupNameEn: "Other Test Church KakaoTalk",
    groupNameKo: "다른 테스트 교회 카카오톡",
    kakaoURL: "https://open.kakao.com/o/other-example-test",
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  await db.collection("resources").doc("test-bible-study").set({
    id: "test-bible-study",
    type: "bible_study",
    category: "bible_study",
    title: {
      zh: "圣经学习测试",
      en: "Bible Study Test",
      ko: "성경 공부 테스트"
    },
    subtitle: {
      zh: "按主题整理的学习资料",
      en: "Study material organized by topic",
      ko: "주제별로 정리한 학습 자료"
    },
    description: {
      zh: "用于 Firebase emulator 集成测试的资源。",
      en: "Resource used by Firebase emulator integration tests.",
      ko: "Firebase emulator 통합 테스트용 자료입니다."
    },
    actionTitle: {
      zh: "开始学习",
      en: "Start Study",
      ko: "공부 시작"
    },
    url: null,
    content: "emulator-test-resource",
    icon: "book",
    isPublished: true,
    sortOrder: 10,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  await db.collection("resources").doc("test-useful-links").set({
    id: "test-useful-links",
    type: "useful_links",
    category: "useful_links",
    title: {
      zh: "常用链接测试",
      en: "Useful Links Test",
      ko: "유용한 링크 테스트"
    },
    subtitle: {
      zh: "官网、视频与报名链接",
      en: "Websites, videos, and signup links",
      ko: "웹사이트, 영상과 신청 링크"
    },
    description: {
      zh: "用于搜索和分类测试。",
      en: "Used for search and category tests.",
      ko: "검색과 분류 테스트에 사용합니다."
    },
    actionTitle: {
      zh: "打开链接",
      en: "Open Links",
      ko: "링크 열기"
    },
    url: "https://example.test/resources",
    content: null,
    icon: "link",
    isPublished: true,
    sortOrder: 20,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  console.log(`Seeded Firebase emulator data for project ${projectId}.`);
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
