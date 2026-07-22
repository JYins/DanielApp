import React, { useEffect, useMemo, useState } from 'react';
import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc
} from 'firebase/firestore';
import { deleteObject, getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { BookOpen, Edit2, FileAudio, FileText, Link as LinkIcon, Plus, Trash2, Upload, XCircle } from 'lucide-react';
import { db, storage } from '../lib/firebase';

type LocalizedText = {
  zh?: string;
  en?: string;
  ko?: string;
};

type ChurchResource = {
  id: string;
  type?: string;
  category?: string;
  title?: LocalizedText;
  subtitle?: LocalizedText;
  description?: LocalizedText;
  actionTitle?: LocalizedText;
  url?: string | null;
  content?: string | null;
  storagePath?: string | null;
  fileName?: string | null;
  fileSize?: number | null;
  fileType?: string | null;
  downloadURL?: string | null;
  audioURL?: string | null;
  audioStoragePath?: string | null;
  audioFileName?: string | null;
  audioFileSize?: number | null;
  audioFileType?: string | null;
  audioDownloadURL?: string | null;
  icon?: string;
  isPublished?: boolean;
  sortOrder?: number;
};

const emptyForm = {
  id: '',
  type: 'hymnbook',
  category: 'hymnbook',
  titleZh: '',
  titleEn: '',
  titleKo: '',
  subtitleZh: '',
  subtitleEn: '',
  subtitleKo: '',
  descriptionZh: '',
  descriptionEn: '',
  descriptionKo: '',
  actionTitleZh: '打开 PDF',
  actionTitleEn: 'Open PDF',
  actionTitleKo: 'PDF 열기',
  externalUrl: '',
  content: '',
  icon: 'doc.richtext',
  isPublished: true,
  sortOrder: 10,
  storagePath: '',
  fileName: '',
  fileSize: 0,
  fileType: '',
  downloadURL: '',
  audioExternalUrl: '',
  audioStoragePath: '',
  audioFileName: '',
  audioFileSize: 0,
  audioFileType: '',
  audioDownloadURL: ''
};

const resourceTypes = [
  { value: 'hymnbook', label: 'Hymnbook' },
  { value: 'church_documents', label: 'Church Documents' },
  { value: 'useful_links', label: 'Useful Links' },
  { value: 'bible_study', label: 'Bible Study' },
  { value: 'q_and_a', label: 'Q & A' },
  { value: 'bible_seminar', label: 'Bible Seminar' }
];

function localized(zh: string, en: string, ko: string) {
  return {
    zh: zh.trim() || en.trim() || ko.trim(),
    en: en.trim() || zh.trim() || ko.trim(),
    ko: ko.trim() || zh.trim() || en.trim()
  };
}

function displayText(value?: LocalizedText) {
  return value?.en || value?.zh || value?.ko || 'Untitled';
}

function slugify(value: string, fallback: string) {
  const slug = value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug || fallback;
}

function storagePathFromUrl(url?: string | null) {
  if (!url) return null;
  try {
    const match = url.match(/\/o\/(.+?)(\?|$)/);
    return match ? decodeURIComponent(match[1]) : null;
  } catch {
    return null;
  }
}

function validatedExternalUrl(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const parsed = new URL(trimmed);
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
    throw new Error('External URL must start with https:// or http://.');
  }
  return parsed.toString();
}

function formatFileSize(bytes?: number | null) {
  if (!bytes) return '—';
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function ResourcesList() {
  const [resources, setResources] = useState<ChurchResource[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [pdfFile, setPdfFile] = useState<File | null>(null);
  const [audioFile, setAudioFile] = useState<File | null>(null);
  const [storagePathToDelete, setStoragePathToDelete] = useState<string | null>(null);
  const [audioPathToDelete, setAudioPathToDelete] = useState<string | null>(null);

  useEffect(() => {
    fetchResources();
  }, []);

  const resourceById = useMemo(() => {
    return Object.fromEntries(resources.map(item => [item.id, item]));
  }, [resources]);

  const fetchResources = async () => {
    setLoading(true);
    try {
      const snap = await getDocs(query(collection(db, 'resources'), orderBy('sortOrder', 'asc')));
      setResources(snap.docs.map(d => ({ id: d.id, ...d.data() } as ChurchResource)));
    } catch (err) {
      console.error('Failed to fetch resources', err);
      alert('Failed to load resources.');
    } finally {
      setLoading(false);
    }
  };

  const openAddModal = () => {
    setForm(emptyForm);
    setPdfFile(null);
    setAudioFile(null);
    setStoragePathToDelete(null);
    setAudioPathToDelete(null);
    setEditingId(null);
    setIsModalOpen(true);
  };

  const openEditModal = (item: ChurchResource) => {
    setEditingId(item.id);
    setPdfFile(null);
    setAudioFile(null);
    setStoragePathToDelete(null);
    setAudioPathToDelete(null);
    setForm({
      id: item.id,
      type: item.type || 'church_documents',
      category: item.category || item.type || 'church_documents',
      titleZh: item.title?.zh || '',
      titleEn: item.title?.en || '',
      titleKo: item.title?.ko || '',
      subtitleZh: item.subtitle?.zh || '',
      subtitleEn: item.subtitle?.en || '',
      subtitleKo: item.subtitle?.ko || '',
      descriptionZh: item.description?.zh || '',
      descriptionEn: item.description?.en || '',
      descriptionKo: item.description?.ko || '',
      actionTitleZh: item.actionTitle?.zh || '',
      actionTitleEn: item.actionTitle?.en || '',
      actionTitleKo: item.actionTitle?.ko || '',
      externalUrl: item.url && item.url !== item.downloadURL ? item.url : '',
      content: item.content || '',
      icon: item.icon || 'doc.richtext',
      isPublished: item.isPublished !== false,
      sortOrder: item.sortOrder || 10,
      storagePath: item.storagePath || '',
      fileName: item.fileName || '',
      fileSize: item.fileSize || 0,
      fileType: item.fileType || '',
      downloadURL: item.downloadURL || '',
      audioExternalUrl: item.audioURL && item.audioURL !== item.audioDownloadURL ? item.audioURL : '',
      audioStoragePath: item.audioStoragePath || '',
      audioFileName: item.audioFileName || '',
      audioFileSize: item.audioFileSize || 0,
      audioFileType: item.audioFileType || '',
      audioDownloadURL: item.audioDownloadURL || ''
    });
    setIsModalOpen(true);
  };

  const handlePdfChange = (file: File | undefined) => {
    if (!file) {
      setPdfFile(null);
      return;
    }
    if (file.type !== 'application/pdf' && !file.name.toLowerCase().endsWith('.pdf')) {
      alert('Please upload a PDF file.');
      return;
    }
    if (file.size > 50 * 1024 * 1024) {
      alert('PDF files must be smaller than 50 MB.');
      return;
    }
    setPdfFile(file);
  };

  const handleAudioChange = (file: File | undefined) => {
    if (!file) {
      setAudioFile(null);
      return;
    }
    const validTypes = ['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/x-m4a'];
    const validExtension = /\.(mp3|m4a|aac)$/i.test(file.name);
    if (!validTypes.includes(file.type) && !validExtension) {
      alert('Please upload an MP3, M4A, or AAC audio file.');
      return;
    }
    if (file.size >= 100 * 1024 * 1024) {
      alert('Audio files must be smaller than 100 MB.');
      return;
    }
    setAudioFile(file);
  };

  const removeExistingPdf = () => {
    if (!window.confirm('Remove the linked PDF from this resource?')) return;
    const path = form.storagePath || storagePathFromUrl(form.downloadURL);
    setStoragePathToDelete(path);
    setForm(prev => ({
      ...prev,
      storagePath: '',
      fileName: '',
      fileSize: 0,
      fileType: '',
      downloadURL: '',
      externalUrl: prev.externalUrl === prev.downloadURL ? '' : prev.externalUrl
    }));
  };

  const removeExistingAudio = () => {
    if (!window.confirm('Remove the linked hymn audio from this resource?')) return;
    const path = form.audioStoragePath || storagePathFromUrl(form.audioDownloadURL);
    setAudioPathToDelete(path);
    setForm(prev => ({
      ...prev,
      audioExternalUrl: '',
      audioStoragePath: '',
      audioFileName: '',
      audioFileSize: 0,
      audioFileType: '',
      audioDownloadURL: ''
    }));
  };

  const handleDelete = async (item: ChurchResource) => {
    if (!window.confirm(`Delete resource "${displayText(item.title)}"?`)) return;
    try {
      const path = item.storagePath || storagePathFromUrl(item.downloadURL);
      const audioPath = item.audioStoragePath || storagePathFromUrl(item.audioDownloadURL);
      await deleteDoc(doc(db, 'resources', item.id));
      for (const filePath of [path, audioPath]) {
        if (filePath) {
          try {
            await deleteObject(ref(storage, filePath));
          } catch (err) {
            console.warn('Resource file could not be deleted from Storage', err);
          }
        }
      }
      await fetchResources();
    } catch (err) {
      console.error('Failed to delete resource', err);
      alert('Failed to delete resource.');
    }
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setSaving(true);
    const uploadedPaths: string[] = [];
    try {
      const title = localized(form.titleZh, form.titleEn, form.titleKo);
      const resourceId = editingId || form.id.trim() || slugify(title.en || title.zh, 'resource');
      const existing = resourceById[resourceId];
      let storagePath = form.storagePath || null;
      let fileName = form.fileName || null;
      let fileSize = form.fileSize || null;
      let fileType = form.fileType || null;
      let downloadURL = form.downloadURL || null;
      let previousPath = storagePathToDelete;
      let audioStoragePath = form.audioStoragePath || null;
      let audioFileName = form.audioFileName || null;
      let audioFileSize = form.audioFileSize || null;
      let audioFileType = form.audioFileType || null;
      let audioDownloadURL = form.audioDownloadURL || null;
      let previousAudioPath = audioPathToDelete;

      if (pdfFile) {
        previousPath = previousPath || storagePath || storagePathFromUrl(downloadURL);

        const safeFileName = pdfFile.name.replace(/[^a-zA-Z0-9._-]+/g, '-');
        storagePath = `resources/${resourceId}/${Date.now()}_${safeFileName}`;
        uploadedPaths.push(storagePath);
        const snapshot = await uploadBytes(ref(storage, storagePath), pdfFile, {
          contentType: 'application/pdf',
          customMetadata: { resourceId }
        });
        downloadURL = await getDownloadURL(snapshot.ref);
        fileName = pdfFile.name;
        fileSize = pdfFile.size;
        fileType = 'application/pdf';
      }

      if (audioFile) {
        previousAudioPath = previousAudioPath || audioStoragePath || storagePathFromUrl(audioDownloadURL);
        const safeAudioName = audioFile.name.replace(/[^a-zA-Z0-9._-]+/g, '-');
        audioStoragePath = `resources/${resourceId}/audio/${Date.now()}_${safeAudioName}`;
        uploadedPaths.push(audioStoragePath);
        const audioSnapshot = await uploadBytes(ref(storage, audioStoragePath), audioFile, {
          contentType: audioFile.type || (audioFile.name.toLowerCase().endsWith('.mp3') ? 'audio/mpeg' : 'audio/mp4'),
          customMetadata: { resourceId, mediaKind: 'hymn-audio' }
        });
        audioDownloadURL = await getDownloadURL(audioSnapshot.ref);
        audioFileName = audioFile.name;
        audioFileSize = audioFile.size;
        audioFileType = audioSnapshot.metadata.contentType || audioFile.type;
      }

      const preferredURL = downloadURL || validatedExternalUrl(form.externalUrl);
      const preferredAudioURL = audioDownloadURL || validatedExternalUrl(form.audioExternalUrl);
      await setDoc(doc(db, 'resources', resourceId), {
        id: resourceId,
        type: form.type,
        category: form.category || form.type,
        title,
        subtitle: localized(form.subtitleZh, form.subtitleEn, form.subtitleKo),
        description: localized(form.descriptionZh, form.descriptionEn, form.descriptionKo),
        actionTitle: localized(form.actionTitleZh, form.actionTitleEn, form.actionTitleKo),
        url: preferredURL,
        content: form.content.trim() || null,
        storagePath,
        fileName,
        fileSize,
        fileType,
        downloadURL,
        audioURL: preferredAudioURL,
        audioStoragePath,
        audioFileName,
        audioFileSize,
        audioFileType,
        audioDownloadURL,
        icon: form.icon.trim() || 'doc.richtext',
        isPublished: form.isPublished,
        accessLevel: 'public',
        sortOrder: Number(form.sortOrder) || 10,
        ...(existing ? {} : { createdAt: serverTimestamp() }),
        updatedAt: serverTimestamp()
      }, { merge: true });
      uploadedPaths.length = 0;

      if (previousPath && previousPath !== storagePath) {
        try {
          await deleteObject(ref(storage, previousPath));
        } catch (err) {
          console.warn('Previous PDF could not be deleted from Storage', err);
        }
      }

      if (previousAudioPath && previousAudioPath !== audioStoragePath) {
        try {
          await deleteObject(ref(storage, previousAudioPath));
        } catch (err) {
          console.warn('Previous audio could not be deleted from Storage', err);
        }
      }

      setIsModalOpen(false);
      await fetchResources();
    } catch (err) {
      for (const uploadedPath of uploadedPaths) {
        try {
          await deleteObject(ref(storage, uploadedPath));
        } catch (cleanupError) {
          console.warn('New resource file could not be cleaned up after save failed', cleanupError);
        }
      }
      console.error('Failed to save resource', err);
      alert('Failed to save resource.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="p-8">Loading...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Resources</h1>
          <p className="mt-1 text-sm text-gray-500">Manage public resources, PDFs, and hymn audio for the iOS Resources tab.</p>
        </div>
        <button
          onClick={openAddModal}
          className="flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-amber-600 hover:bg-amber-700"
        >
          <Plus className="h-4 w-4 mr-2" /> Add Resource
        </button>
      </div>

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Resource</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">File</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {resources.map(item => (
              <tr key={item.id}>
                <td className="px-6 py-4">
                  <div className="flex items-start">
                    <div className="h-10 w-10 rounded bg-amber-50 flex items-center justify-center mr-3">
                      {item.downloadURL ? <FileText className="h-5 w-5 text-amber-600" /> : <BookOpen className="h-5 w-5 text-amber-600" />}
                    </div>
                    <div>
                      <div className="text-sm font-medium text-gray-900">{displayText(item.title)}</div>
                      <div className="text-xs text-gray-500">{item.id}</div>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4 text-sm text-gray-700">{item.type || '—'}</td>
                <td className="px-6 py-4 text-sm text-gray-700">
                  <div className="flex flex-col items-start gap-1">
                    {item.downloadURL ? (
                      <a href={item.downloadURL} target="_blank" rel="noreferrer" className="inline-flex items-center text-amber-700 hover:text-amber-900">
                        <FileText className="h-4 w-4 mr-1" />
                        {item.fileName || 'PDF'} · {formatFileSize(item.fileSize)}
                      </a>
                    ) : item.url ? (
                      <a href={item.url} target="_blank" rel="noreferrer" className="inline-flex items-center text-blue-700 hover:text-blue-900">
                        <LinkIcon className="h-4 w-4 mr-1" />
                        Link
                      </a>
                    ) : null}
                    {(item.audioDownloadURL || item.audioURL) && (
                      <a href={item.audioDownloadURL || item.audioURL || '#'} target="_blank" rel="noreferrer" className="inline-flex items-center text-orange-700 hover:text-orange-900">
                        <FileAudio className="h-4 w-4 mr-1" />
                        {item.audioFileName || 'Hymn audio'} {item.audioFileSize ? `· ${formatFileSize(item.audioFileSize)}` : ''}
                      </a>
                    )}
                    {!item.downloadURL && !item.url && !item.audioDownloadURL && !item.audioURL && '—'}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${item.isPublished !== false ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}`}>
                    {item.isPublished !== false ? 'Published' : 'Draft'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button onClick={() => openEditModal(item)} className="text-amber-700 hover:text-amber-900 mr-4 inline-block">
                    <Edit2 className="h-4 w-4" />
                  </button>
                  <button onClick={() => handleDelete(item)} className="text-red-600 hover:text-red-900 inline-block">
                    <Trash2 className="h-4 w-4" />
                  </button>
                </td>
              </tr>
            ))}
            {resources.length === 0 && (
              <tr>
                <td colSpan={5} className="px-6 py-4 text-center text-sm text-gray-500">No resources found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {isModalOpen && (
        <div className="fixed z-10 inset-0 overflow-y-auto">
          <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75" onClick={() => setIsModalOpen(false)}></div>
            <span className="hidden sm:inline-block sm:align-middle sm:h-screen">&#8203;</span>
            <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-3xl w-full">
              <form onSubmit={handleSubmit}>
                <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4 max-h-[75vh] overflow-y-auto">
                  <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                    {editingId ? 'Edit Resource' : 'Add Resource'}
                  </h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <label className="block text-sm font-medium text-gray-700">
                      Resource ID
                      <input value={form.id} disabled={!!editingId} onChange={e => setForm(prev => ({ ...prev, id: e.target.value }))} placeholder="auto-from-title" className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm disabled:bg-gray-100" />
                    </label>
                    <label className="block text-sm font-medium text-gray-700">
                      Type
                      <select value={form.type} onChange={e => setForm(prev => ({ ...prev, type: e.target.value, category: e.target.value }))} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm">
                        {resourceTypes.map(type => <option key={type.value} value={type.value}>{type.label}</option>)}
                      </select>
                    </label>
                    <label className="block text-sm font-medium text-gray-700">
                      Icon
                      <input value={form.icon} onChange={e => setForm(prev => ({ ...prev, icon: e.target.value }))} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </label>
                    <label className="block text-sm font-medium text-gray-700">
                      Sort Order
                      <input type="number" value={form.sortOrder} onChange={e => setForm(prev => ({ ...prev, sortOrder: Number(e.target.value) }))} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </label>
                  </div>

                  <div className="mt-5 grid grid-cols-1 md:grid-cols-3 gap-4">
                    <TextInput label="Title ZH" value={form.titleZh} onChange={value => setForm(prev => ({ ...prev, titleZh: value }))} required />
                    <TextInput label="Title EN" value={form.titleEn} onChange={value => setForm(prev => ({ ...prev, titleEn: value }))} />
                    <TextInput label="Title KO" value={form.titleKo} onChange={value => setForm(prev => ({ ...prev, titleKo: value }))} />
                    <TextInput label="Subtitle ZH" value={form.subtitleZh} onChange={value => setForm(prev => ({ ...prev, subtitleZh: value }))} required />
                    <TextInput label="Subtitle EN" value={form.subtitleEn} onChange={value => setForm(prev => ({ ...prev, subtitleEn: value }))} />
                    <TextInput label="Subtitle KO" value={form.subtitleKo} onChange={value => setForm(prev => ({ ...prev, subtitleKo: value }))} />
                    <TextInput label="Action ZH" value={form.actionTitleZh} onChange={value => setForm(prev => ({ ...prev, actionTitleZh: value }))} required />
                    <TextInput label="Action EN" value={form.actionTitleEn} onChange={value => setForm(prev => ({ ...prev, actionTitleEn: value }))} />
                    <TextInput label="Action KO" value={form.actionTitleKo} onChange={value => setForm(prev => ({ ...prev, actionTitleKo: value }))} />
                  </div>

                  <div className="mt-5 grid grid-cols-1 md:grid-cols-3 gap-4">
                    <TextArea label="Description ZH" value={form.descriptionZh} onChange={value => setForm(prev => ({ ...prev, descriptionZh: value }))} required />
                    <TextArea label="Description EN" value={form.descriptionEn} onChange={value => setForm(prev => ({ ...prev, descriptionEn: value }))} />
                    <TextArea label="Description KO" value={form.descriptionKo} onChange={value => setForm(prev => ({ ...prev, descriptionKo: value }))} />
                  </div>

                  <div className="mt-5 grid grid-cols-1 md:grid-cols-2 gap-4">
                    <label className="block text-sm font-medium text-gray-700">
                      External URL
                      <input value={form.externalUrl} onChange={e => setForm(prev => ({ ...prev, externalUrl: e.target.value }))} placeholder="Optional if no PDF" className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </label>
                    <label className="block text-sm font-medium text-gray-700">
                      External Audio URL
                      <input value={form.audioExternalUrl} onChange={e => setForm(prev => ({ ...prev, audioExternalUrl: e.target.value }))} placeholder="Optional MP3/M4A stream for Hymnbook" className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </label>
                    <label className="block text-sm font-medium text-gray-700">
                      Internal Content
                      <input value={form.content} onChange={e => setForm(prev => ({ ...prev, content: e.target.value }))} placeholder="Optional short internal note" className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </label>
                  </div>

                  {form.type === 'hymnbook' && (
                    <div className="mt-5 rounded-md border border-orange-200 bg-orange-50/40 p-4">
                      <div className="flex items-center justify-between gap-4">
                        <div>
                          <h4 className="text-sm font-semibold text-gray-900">Hymn Audio</h4>
                          <p className="text-xs text-gray-500">MP3, M4A, or AAC under 100 MB. The iOS reader keeps this playing while the PDF is visible.</p>
                        </div>
                        <label className="inline-flex shrink-0 items-center px-3 py-2 rounded-md bg-orange-100 text-orange-800 text-sm font-medium cursor-pointer hover:bg-orange-200">
                          <Upload className="h-4 w-4 mr-2" />
                          Choose Audio
                          <input type="file" accept="audio/mpeg,audio/mp4,audio/aac,.mp3,.m4a,.aac" className="hidden" onChange={e => handleAudioChange(e.target.files?.[0])} />
                        </label>
                      </div>
                      {(audioFile || form.audioDownloadURL || form.audioExternalUrl) && (
                        <div className="mt-3 flex items-center justify-between rounded bg-white px-3 py-2">
                          <div className="text-sm text-gray-700">
                            <FileAudio className="h-4 w-4 inline mr-1 text-orange-600" />
                            {audioFile?.name || form.audioFileName || (form.audioExternalUrl ? 'External audio' : 'Current audio')}
                            {(audioFile?.size || form.audioFileSize) ? ` · ${formatFileSize(audioFile?.size || form.audioFileSize)}` : ''}
                          </div>
                          {(form.audioDownloadURL || form.audioExternalUrl) && !audioFile && (
                            <button type="button" aria-label="Remove hymn audio" onClick={removeExistingAudio} className="text-red-600 hover:text-red-800">
                              <XCircle className="h-4 w-4" />
                            </button>
                          )}
                        </div>
                      )}
                    </div>
                  )}

                  <div className="mt-5 rounded-md border border-gray-200 p-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h4 className="text-sm font-semibold text-gray-900">PDF File</h4>
                        <p className="text-xs text-gray-500">Only PDF files under 50 MB are allowed.</p>
                      </div>
                      <label className="inline-flex items-center px-3 py-2 rounded-md bg-amber-50 text-amber-800 text-sm font-medium cursor-pointer hover:bg-amber-100">
                        <Upload className="h-4 w-4 mr-2" />
                        Choose PDF
                        <input type="file" accept="application/pdf,.pdf" className="hidden" onChange={e => handlePdfChange(e.target.files?.[0])} />
                      </label>
                    </div>
                    {(pdfFile || form.downloadURL) && (
                      <div className="mt-3 flex items-center justify-between rounded bg-gray-50 px-3 py-2">
                        <div className="text-sm text-gray-700">
                          <FileText className="h-4 w-4 inline mr-1 text-amber-600" />
                          {pdfFile?.name || form.fileName || 'Current PDF'} · {formatFileSize(pdfFile?.size || form.fileSize)}
                        </div>
                        {form.downloadURL && !pdfFile && (
                          <button type="button" onClick={removeExistingPdf} className="text-red-600 hover:text-red-800">
                            <XCircle className="h-4 w-4" />
                          </button>
                        )}
                      </div>
                    )}
                  </div>

                  <div className="mt-5 flex items-center space-x-6">
                    <label className="flex items-center text-sm text-gray-900">
                      <input type="checkbox" checked={form.isPublished} onChange={e => setForm(prev => ({ ...prev, isPublished: e.target.checked }))} className="h-4 w-4 text-amber-600 focus:ring-amber-500 border-gray-300 rounded mr-2" />
                      Published
                    </label>
                    <span className="text-sm text-gray-500">Published resources are public in the Canada pilot.</span>
                  </div>
                </div>
                <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                  <button type="submit" disabled={saving} className="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-amber-600 text-base font-medium text-white hover:bg-amber-700 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50">
                    {saving ? 'Saving...' : 'Save Resource'}
                  </button>
                  <button type="button" onClick={() => setIsModalOpen(false)} className="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 sm:mt-0 sm:w-auto sm:text-sm">
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function TextInput({ label, value, onChange, required }: { label: string; value: string; onChange: (value: string) => void; required?: boolean }) {
  return (
    <label className="block text-sm font-medium text-gray-700">
      {label}
      <input required={required} value={value} onChange={e => onChange(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
    </label>
  );
}

function TextArea({ label, value, onChange, required }: { label: string; value: string; onChange: (value: string) => void; required?: boolean }) {
  return (
    <label className="block text-sm font-medium text-gray-700">
      {label}
      <textarea required={required} rows={4} value={value} onChange={e => onChange(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
    </label>
  );
}
