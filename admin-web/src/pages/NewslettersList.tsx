import React, { useEffect, useState } from 'react';
import { collection, query, getDocs, addDoc, updateDoc, deleteDoc, doc, orderBy, Timestamp } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../lib/firebase';
import { Plus, Edit2, Trash2, Image as ImageIcon, XCircle } from 'lucide-react';

export default function NewslettersList() {
  const [newsletters, setNewsletters] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  
  // Form state
  const [publishDate, setPublishDate] = useState(new Date().toISOString().split('T')[0]);
  const [captionCn, setCaptionCn] = useState('');
  const [captionEn, setCaptionEn] = useState('');
  const [captionKr, setCaptionKr] = useState('');
  const [published, setPublished] = useState(true);
  const [imageFiles, setImageFiles] = useState<FileList | null>(null);
  const [existingImages, setExistingImages] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchNewsletters();
  }, []);

  const fetchNewsletters = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'newsletters'), orderBy('publishDate', 'desc'));
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
    setExistingImages(item.image_urls || []);
    setEditingId(item.id);
    setIsModalOpen(true);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this newsletter?')) return;
    try {
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
          const storageRef = ref(storage, `newsletters/${publishDate}_${Date.now()}_${file.name}`);
          const snapshot = await uploadBytes(storageRef, file);
          const url = await getDownloadURL(snapshot.ref);
          imageUrls.push(url);
        }
      }

      // Convert date string to Firestore Timestamp (iOS expects Timestamp type)
      const dateObj = new Date(publishDate + 'T00:00:00');
      const newsletterData = {
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
      alert("Failed to save newsletter");
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
        <h1 className="text-2xl font-bold text-gray-900">Newsletters</h1>
        <button
          onClick={openAddModal}
          className="flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700"
        >
          <Plus className="h-4 w-4 mr-2" /> Add New
        </button>
      </div>

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Image</th>
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
                <td colSpan={5} className="px-6 py-4 text-center text-sm text-gray-500">No newsletters found.</td>
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
                    {editingId ? 'Edit Newsletter' : 'Add New Newsletter'}
                  </h3>
                  <div className="space-y-4">
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
