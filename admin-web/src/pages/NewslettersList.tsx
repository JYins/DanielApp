import React, { useEffect, useState } from 'react';
import { collection, query, getDocs, addDoc, updateDoc, deleteDoc, doc, orderBy, Timestamp, where } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';
import { db, storage } from '../lib/firebase';
import { Plus, Edit2, Trash2, Image as ImageIcon, XCircle } from 'lucide-react';
import { useAuthContext } from '../components/AuthProvider';

type Branch = { id: string; name?: { en?: string; zh?: string; ko?: string }; regionId?: string };

function branchName(branch?: Branch) {
  return branch?.name?.en || branch?.name?.zh || branch?.name?.ko || branch?.id || '—';
}

// Helper: extract Storage path from a Firebase download URL
function getStoragePathFromUrl(url: string): string | null {
  try {
    const match = url.match(/\/o\/(.+?)(\?|$)/);
    if (match) return decodeURIComponent(match[1]);
  } catch {}
  return null;
}

export default function NewslettersList() {
  const { adminProfile } = useAuthContext();
  const accessRole = adminProfile?.accessRole || adminProfile?.role;
  const isGlobalAdmin = ['admin', 'global_admin'].includes(accessRole);
  const isRegionAdmin = accessRole === 'region_admin';
  const [newsletters, setNewsletters] = useState<any[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  
  // Form state
  const [publishDate, setPublishDate] = useState(new Date().toISOString().split('T')[0]);
  const [captionCn, setCaptionCn] = useState('');
  const [captionEn, setCaptionEn] = useState('');
  const [captionKr, setCaptionKr] = useState('');
  const [published, setPublished] = useState(true);
  const [branchId, setBranchId] = useState(adminProfile?.branchId || '');
  const [contentType, setContentType] = useState<'announcement' | 'newsletter'>('announcement');
  const [imageFiles, setImageFiles] = useState<FileList | null>(null);
  const [existingImages, setExistingImages] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const load = async () => {
      const loadedBranches = await fetchBranches();
      await fetchNewsletters(loadedBranches);
    };
    load();
  }, [adminProfile?.id]);

  const fetchBranches = async () => {
    try {
      let branchesQuery = query(collection(db, 'branches'), orderBy('sortOrder', 'asc'));
      if (isRegionAdmin && adminProfile?.regionId) {
        branchesQuery = query(collection(db, 'branches'), where('regionId', '==', adminProfile.regionId), orderBy('sortOrder', 'asc'));
      }
      const snap = await getDocs(branchesQuery);
      let loaded = snap.docs.map(item => ({ id: item.id, ...item.data() } as Branch));
      if (!isGlobalAdmin && !isRegionAdmin) loaded = loaded.filter(item => item.id === adminProfile?.branchId);
      setBranches(loaded);
      setBranchId(current => current || loaded[0]?.id || '');
      return loaded;
    } catch (err) {
      console.error('Failed to load churches', err);
      return [] as Branch[];
    }
  };

  const fetchNewsletters = async (scopedBranches: Branch[] = branches) => {
    setLoading(true);
    try {
      let q = query(collection(db, 'newsletters'), orderBy('publishDate', 'desc'));
      if (!isGlobalAdmin && !isRegionAdmin && adminProfile?.branchId) {
        q = query(collection(db, 'newsletters'), where('branchId', '==', adminProfile.branchId), orderBy('publishDate', 'desc'));
      } else if (isRegionAdmin && adminProfile?.regionId) {
        const permittedBranches = scopedBranches.filter(item => item.regionId === adminProfile.regionId).map(item => item.id);
        if (permittedBranches.length === 0) {
          setNewsletters([]);
          return;
        }
        if (permittedBranches.length > 30) throw new Error('Region has too many churches for this pilot view.');
        q = query(collection(db, 'newsletters'), where('branchId', 'in', permittedBranches), orderBy('publishDate', 'desc'));
      }
      const snap = await getDocs(q);
      setNewsletters(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setPublishDate(new Date().toISOString().split('T')[0]);
    setCaptionCn('');
    setCaptionEn('');
    setCaptionKr('');
    setPublished(true);
    setBranchId(adminProfile?.branchId || branches[0]?.id || '');
    setContentType('announcement');
    setImageFiles(null);
    setExistingImages([]);
    setEditingId(null);
  };

  const openAddModal = () => {
    resetForm();
    setIsModalOpen(true);
  };

  const openEditModal = (item: any) => {
    // Handle Timestamp or string publishDate
    const pd = item.publishDate?.toDate ? item.publishDate.toDate().toISOString().split('T')[0] : (item.publishDate || new Date().toISOString().split('T')[0]);
    setPublishDate(pd);
    setCaptionCn(item.caption_cn || '');
    setCaptionEn(item.caption_en || '');
    setCaptionKr(item.caption_kr || '');
    setPublished(item.published ?? true);
    setBranchId(item.branchId || adminProfile?.branchId || '');
    setContentType(item.contentType === 'newsletter' ? 'newsletter' : 'announcement');
    setExistingImages(item.image_urls || []);
    setEditingId(item.id);
    setIsModalOpen(true);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this newsletter?')) return;
    try {
      // Delete images from Storage
      const item = newsletters.find(n => n.id === id);
      for (const url of (item?.image_urls || [])) {
        const path = getStoragePathFromUrl(url);
        if (path) {
          try { await deleteObject(ref(storage, path)); } catch {}
        }
      }
      // Delete Firestore document
      await deleteDoc(doc(db, 'newsletters', id));
      setNewsletters(prev => prev.filter(c => c.id !== id));
    } catch (err) {
      alert("Failed to delete newsletter");
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      let imageUrls = [...existingImages];

      if (imageFiles && imageFiles.length > 0) {
        for (let i = 0; i < imageFiles.length; i++) {
          const file = imageFiles[i];
          if (!branchId) throw new Error('Select a church before uploading images.');
          const safeFileName = file.name.replace(/[^a-zA-Z0-9._-]+/g, '-');
          const storageRef = ref(storage, `newsletters/${branchId}/${publishDate}_${Date.now()}_${safeFileName}`);
          const snapshot = await uploadBytes(storageRef, file);
          const url = await getDownloadURL(snapshot.ref);
          imageUrls.push(url);
        }
      }

      // Convert date string to Firestore Timestamp (iOS expects Timestamp type)
      const dateObj = new Date(publishDate + 'T00:00:00');
      if (!branchId) throw new Error('Select a church before saving.');
      const newsletterData = {
        branchId,
        contentType,
        publishDate: Timestamp.fromDate(dateObj),
        caption_cn: captionCn,
        caption_en: captionEn,
        caption_kr: captionKr,
        published,
        image_urls: imageUrls,
        updatedAt: Timestamp.fromDate(new Date())
      };

      if (editingId) {
        await updateDoc(doc(db, 'newsletters', editingId), newsletterData);
      } else {
        await addDoc(collection(db, 'newsletters'), {
          ...newsletterData,
          createdAt: new Date()
        });
      }

      setIsModalOpen(false);
      fetchNewsletters();
    } catch (err) {
      console.error(err);
      alert(err instanceof Error ? err.message : "Failed to save church content");
    } finally {
      setSaving(false);
    }
  };

  const removeExistingImage = (index: number) => {
    setExistingImages(prev => prev.filter((_, i) => i !== index));
  };

  if (loading) return <div className="p-8">Loading...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.18em] text-amber-600">Connect</p>
          <h1 className="mt-1 text-2xl font-bold text-gray-900">Announcements & Newsletter</h1>
        </div>
        <button
          onClick={openAddModal}
          className="flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700"
        >
          <Plus className="h-4 w-4 mr-2" /> Add Content
        </button>
      </div>

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Image</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Church / Type</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Excerpt (CN)</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {newsletters.map((item) => (
              <tr key={item.id}>
                <td className="px-6 py-4 whitespace-nowrap">
                  {item.image_urls && item.image_urls.length > 0 ? (
                    <img src={item.image_urls[0]} alt="" className="h-10 w-10 rounded object-cover" />
                  ) : (
                    <div className="h-10 w-10 rounded bg-gray-100 flex items-center justify-center">
                      <ImageIcon className="h-5 w-5 text-gray-400" />
                    </div>
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm font-medium text-gray-900">{branchName(branches.find(branch => branch.id === item.branchId))}</div>
                  <div className="text-xs capitalize text-gray-500">{item.contentType || 'newsletter'}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{item.publishDate?.toDate ? item.publishDate.toDate().toLocaleDateString() : item.publishDate}</td>
                <td className="px-6 py-4">
                  <div className="text-sm text-gray-900 line-clamp-2 max-w-xs">{item.caption_cn}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${item.published ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}`}>
                    {item.published ? 'Published' : 'Draft'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button onClick={() => openEditModal(item)} className="text-green-600 hover:text-green-900 mr-4 inline-block">
                    <Edit2 className="h-4 w-4" />
                  </button>
                  <button onClick={() => handleDelete(item.id)} className="text-red-600 hover:text-red-900 inline-block">
                    <Trash2 className="h-4 w-4" />
                  </button>
                </td>
              </tr>
            ))}
            {newsletters.length === 0 && (
              <tr>
                <td colSpan={6} className="px-6 py-4 text-center text-sm text-gray-500">No church content found.</td>
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
            <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg w-full">
              <form onSubmit={handleSubmit}>
                <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4 max-h-[70vh] overflow-y-auto">
                  <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                    {editingId ? 'Edit Church Content' : 'Add Church Content'}
                  </h3>
                  <div className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Church</label>
                      <select required value={branchId} disabled={!isGlobalAdmin && !isRegionAdmin} onChange={e => setBranchId(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm">
                        <option value="">Select church</option>
                        {branches.map(branch => <option key={branch.id} value={branch.id}>{branchName(branch)}</option>)}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Content Type</label>
                      <select value={contentType} onChange={e => setContentType(e.target.value as 'announcement' | 'newsletter')} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-amber-500 focus:border-amber-500 sm:text-sm">
                        <option value="announcement">Announcement</option>
                        <option value="newsletter">Newsletter</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Publish Date</label>
                      <input type="date" required value={publishDate} onChange={e => setPublishDate(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-green-500 focus:border-green-500 sm:text-sm" />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Chinese Text</label>
                      <textarea rows={5} required value={captionCn} onChange={e => setCaptionCn(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-green-500 focus:border-green-500 sm:text-sm" />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">English Text</label>
                      <textarea rows={5} value={captionEn} onChange={e => setCaptionEn(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-green-500 focus:border-green-500 sm:text-sm" />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Korean Text</label>
                      <textarea rows={5} value={captionKr} onChange={e => setCaptionKr(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:ring-green-500 focus:border-green-500 sm:text-sm" />
                    </div>
                    <div className="flex items-center">
                      <input id="published" type="checkbox" checked={published} onChange={e => setPublished(e.target.checked)} className="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded" />
                      <label htmlFor="published" className="ml-2 block text-sm text-gray-900">
                        Published
                      </label>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Images</label>
                      <div className="mt-2 flex items-center space-x-2">
                        {existingImages.map((url, i) => (
                          <div key={i} className="relative">
                            <img src={url} alt="" className="h-16 w-16 object-cover rounded" />
                            <button type="button" onClick={() => removeExistingImage(i)} className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 shadow-sm">
                              <XCircle className="h-3 w-3" />
                            </button>
                          </div>
                        ))}
                      </div>
                      <input type="file" multiple accept="image/*" onChange={e => setImageFiles(e.target.files)} className="mt-3 block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-green-50 file:text-green-700 hover:file:bg-green-100" />
                    </div>
                  </div>
                </div>
                <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse border-t border-gray-200">
                  <button type="submit" disabled={saving} className="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-green-600 text-base font-medium text-white hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 sm:ml-3 sm:w-auto sm:text-sm">
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                  <button type="button" onClick={() => setIsModalOpen(false)} className="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
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
