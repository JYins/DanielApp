#!/usr/bin/env node

const fs = require("fs");
const { execFileSync } = require("child_process");
const auth = require("./firebase-cli-auth");

function defaultProjectId() {
  if (!fs.existsSync("GoogleService-Info.plist")) {
    return "daniel1-ca1e7";
  }

  try {
    const projectId = execFileSync(
      "/usr/libexec/PlistBuddy",
      ["-c", "Print :PROJECT_ID", "GoogleService-Info.plist"],
      { encoding: "utf8" }
    ).trim();
    return projectId || "daniel1-ca1e7";
  } catch {
    return "daniel1-ca1e7";
  }
}

const args = new Set(process.argv.slice(2));
const isConfirmed = args.has("--confirm-production-resources");
const shouldCheckOnly = args.has("--check");
const projectArgIndex = process.argv.indexOf("--project");
const projectId =
  projectArgIndex >= 0 && process.argv[projectArgIndex + 1]
    ? process.argv[projectArgIndex + 1]
    : process.env.GCLOUD_PROJECT || defaultProjectId();

if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error("Refusing to run: emulator env vars are set, but this script is for production Firestore.");
  process.exit(1);
}

const resources = [
  {
    id: "hymnbook",
    type: "hymnbook",
    category: "hymnbook",
    title: {
      zh: "诗歌本",
      en: "Hymnbook",
      ko: "찬송가"
    },
    subtitle: {
      zh: "赞美诗、谱面与敬拜资源",
      en: "Hymns, song sheets, and worship resources",
      ko: "찬양, 악보와 예배 자료"
    },
    description: {
      zh: "第一版先作为目录入口。未来可接入 Praise PDF、歌单和按语言分类的诗歌资源。",
      en: "This starts as a directory entry. It can later connect to Praise PDFs, song lists, and language-specific hymn resources.",
      ko: "첫 버전은 자료실 입구로 시작합니다. 추후 찬양 PDF, 곡 목록, 언어별 찬양 자료와 연결할 수 있습니다."
    },
    actionTitle: {
      zh: "打开诗歌本",
      en: "Open Hymnbook",
      ko: "찬송가 열기"
    },
    url: null,
    content: null,
    icon: "music.note.list",
    isPublished: true,
    accessLevel: "public",
    sortOrder: 10
  },
  {
    id: "church-documents",
    type: "church_documents",
    category: "church_documents",
    title: {
      zh: "教会文件",
      en: "Church Documents",
      ko: "교회 문서"
    },
    subtitle: {
      zh: "共同阅读的文件、PDF 与说明",
      en: "Shared documents, PDFs, and guides",
      ko: "함께 읽는 문서, PDF와 안내"
    },
    description: {
      zh: "可用于放置信仰基础、聚会说明、服事守则和其他公开材料。第一阶段先建立 Firebase 资源目录，后续再交给 admin 管理。",
      en: "Use this for faith foundations, meeting guides, serving guidelines, and other shared materials. This phase establishes the Firebase resource directory before admin management is added.",
      ko: "신앙 기초, 모임 안내, 섬김 지침과 공유 자료를 담을 수 있습니다. 첫 단계는 Firebase 자료실을 만들고 이후 관리자 관리로 확장합니다."
    },
    actionTitle: {
      zh: "查看文件",
      en: "View Documents",
      ko: "문서 보기"
    },
    url: null,
    content: null,
    icon: "doc.text",
    isPublished: true,
    accessLevel: "public",
    sortOrder: 20
  },
  {
    id: "useful-links",
    type: "useful_links",
    category: "useful_links",
    title: {
      zh: "常用链接",
      en: "Useful Links",
      ko: "유용한 링크"
    },
    subtitle: {
      zh: "官方网站、视频、报名与外部资源",
      en: "Official sites, videos, signups, and external resources",
      ko: "공식 사이트, 영상, 신청과 외부 자료"
    },
    description: {
      zh: "这里可以集中整理教会官网、YouTube、Instagram、活动报名和长期资源链接。",
      en: "Collect church websites, YouTube, Instagram, event signups, and long-lived resource links here.",
      ko: "교회 웹사이트, YouTube, Instagram, 행사 신청과 장기 자료 링크를 모아둘 수 있습니다."
    },
    actionTitle: {
      zh: "打开链接",
      en: "Open Links",
      ko: "링크 열기"
    },
    url: "https://www.youtube.com/channel/UCv_vGKqXZGHjO6jRYQtufuA",
    content: null,
    icon: "link",
    isPublished: true,
    accessLevel: "public",
    sortOrder: 30
  },
  {
    id: "bible-study",
    type: "bible_study",
    category: "bible_study",
    title: {
      zh: "圣经学习",
      en: "Bible Study",
      ko: "성경 공부"
    },
    subtitle: {
      zh: "按主题或书卷整理的学习材料",
      en: "Study materials by topic or Bible book",
      ko: "주제나 성경 권별 학습 자료"
    },
    description: {
      zh: "对应按书卷、主题和问答展开的 Bible Study 方向。第一版先提供 Firebase 条目和详情页。",
      en: "This follows the direction for Bible Study by book, topic, and Q&A. The first phase provides Firebase entries and detail pages.",
      ko: "성경 권별, 주제별, Q&A 성경 공부 방향을 따릅니다. 첫 단계는 Firebase 항목과 상세 화면을 제공합니다."
    },
    actionTitle: {
      zh: "开始学习",
      en: "Start Study",
      ko: "공부 시작"
    },
    url: null,
    content: null,
    icon: "book",
    isPublished: true,
    accessLevel: "public",
    sortOrder: 40
  },
  {
    id: "bible-seminar",
    type: "bible_seminar",
    category: "bible_seminar",
    title: {
      zh: "圣经讲座",
      en: "Bible Seminar",
      ko: "성경 세미나"
    },
    subtitle: {
      zh: "讲座、课程与集体学习安排",
      en: "Seminars, courses, and group study plans",
      ko: "세미나, 과정과 공동 학습 일정"
    },
    description: {
      zh: "未来可接入活动报名、讲义 PDF 和讲座回放。当前先提供产品结构和可点击详情。",
      en: "This can later connect to event registration, handout PDFs, and seminar replays. For now it establishes the product structure and clickable detail.",
      ko: "추후 행사 신청, 강의안 PDF와 세미나 다시보기로 연결할 수 있습니다. 현재는 제품 구조와 상세 화면을 먼저 마련합니다."
    },
    actionTitle: {
      zh: "查看讲座",
      en: "View Seminars",
      ko: "세미나 보기"
    },
    url: null,
    content: null,
    icon: "person.2.wave.2",
    isPublished: true,
    accessLevel: "public",
    sortOrder: 50
  }
];

function fieldValue(value) {
  if (value === null || value === undefined) {
    return { nullValue: "NULL_VALUE" };
  }
  if (typeof value === "string") {
    return { stringValue: value };
  }
  if (typeof value === "boolean") {
    return { booleanValue: value };
  }
  if (Number.isInteger(value)) {
    return { integerValue: String(value) };
  }
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(Object.entries(value).map(([key, nested]) => [key, fieldValue(nested)]))
      }
    };
  }
  throw new Error(`Unsupported Firestore value: ${value}`);
}

function resourceFields(resource, nowIso) {
  return Object.fromEntries(
    Object.entries({
      ...resource,
      createdAt: { timestampValue: nowIso },
      updatedAt: { timestampValue: nowIso }
    }).map(([key, value]) => {
      if (value && typeof value === "object" && "timestampValue" in value) {
        return [key, value];
      }
      return [key, fieldValue(value)];
    })
  );
}

async function accessToken() {
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("No Firebase CLI refresh token found. Run firebase login --reauth first.");
  }
  const tokenData = await auth.getAccessToken(account.tokens.refresh_token, []);
  return tokenData.access_token;
}

async function firestoreFetch(path, options = {}) {
  const token = await accessToken();
  const response = await fetch(`https://firestore.googleapis.com/v1/${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers || {})
    }
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${response.status} ${body.error?.status || ""}: ${body.error?.message || "Firestore request failed"}`);
  }
  return body;
}

async function collectionCount(collectionId) {
  const result = await firestoreFetch(
    `projects/${projectId}/databases/(default)/documents/${collectionId}?pageSize=100`
  );
  return result.documents?.length || 0;
}

async function checkStatus() {
  const [resourceCount, newsletterCount, userCount] = await Promise.all([
    collectionCount("resources"),
    collectionCount("newsletters"),
    collectionCount("users")
  ]);
  console.log(`Project: ${projectId}`);
  console.log(`resources: ${resourceCount}`);
  console.log(`newsletters: ${newsletterCount}`);
  console.log(`users: ${userCount}`);
}

async function seedResources() {
  const nowIso = new Date().toISOString();
  const writes = resources.map((resource) => ({
    update: {
      name: `projects/${projectId}/databases/(default)/documents/resources/${resource.id}`,
      fields: resourceFields(resource, nowIso)
    }
  }));

  await firestoreFetch(`projects/${projectId}/databases/(default)/documents:commit`, {
    method: "POST",
    body: JSON.stringify({ writes })
  });

  console.log(`Upserted ${resources.length} production resources into project ${projectId}.`);
}

async function main() {
  if (shouldCheckOnly) {
    await checkStatus();
    return;
  }

  console.log(`Prepared ${resources.length} production resource documents for ${projectId}.`);
  for (const resource of resources) {
    console.log(`- ${resource.id}: ${resource.title.zh} / ${resource.title.en} / ${resource.title.ko}`);
  }

  if (!isConfirmed) {
    console.log("Dry run only. Re-run with --confirm-production-resources to write production Firestore.");
    return;
  }

  await seedResources();
  await checkStatus();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
