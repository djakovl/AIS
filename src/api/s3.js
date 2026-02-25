// Обёртки над S3 API: бакеты, папки, файлы, загрузка, скачивание, шаринг
import { request } from './client.js';

/*
 List buckets for user.
 {string} userId - User UUID
 {Promise<{ ok: boolean, data?: any, error?: { code: string, message: string } }>}
 */
export function listBuckets(userId) {
  return request('GET', '/files/buckets/list', { userId });
}

//Create bucket.
export function createBucket(userId, { name, description, isPublic }) {
  return request('POST', '/files/buckets/create', {
    userId,
    body: { name, description, isPublic },
  });
}

//Delete bucket.

export function deleteBucket(userId, bucketId) {
  return request('DELETE', `/files/buckets/${bucketId}`, { userId });
}

//Create folder.

export function createFolder(userId, { bucketId, parentFolderId, name }) {
  return request('POST', '/files/folders/create', {
    userId,
    body: { bucketId, parentFolderId, name },
  });
}

//List files and folders in bucket.

export function listFiles(userId, { bucketId, parentFolderId }) {
  const params = new URLSearchParams({ bucket_id: bucketId });
  if (parentFolderId) {
    params.set('parent_folder_id', parentFolderId);
  }
  return request('GET', `/files/list?${params}`, { userId });
}

//Upload file (multipart/form-data).

export function uploadFile(userId, formData) {
  return request('POST', '/files/upload', { userId, formData });
}

//Download file. Returns Blob for use with URL.createObjectURL or <a download>.

export async function downloadFile(userId, fileId) {
  const params = new URLSearchParams({ file_id: fileId });
  return request('GET', `/files/download?${params}`, { userId, binary: true });
}

//Move file or folder.

export function moveFile(userId, { fileId, newParentFolderId, newBucketId }) {
  return request('POST', '/files/move', {
    userId,
    body: { fileId, newParentFolderId, newBucketId },
  });
}

// Delete file or folder.

export function deleteFile(userId, fileId) {
  return request('DELETE', `/files/${fileId}`, { userId });
}

//Create shared link for file.

export function createShareLink(userId, { fileId, expiresAt, maxDownloads }) {
  return request('POST', '/files/share/create', {
    userId,
    body: { fileId, expiresAt, maxDownloads },
  });
}

//Download file by shared link token (no X-User-Id required).

export async function getSharedFile(token) {
  const res = await request('GET', `/files/shared/${encodeURIComponent(token)}`, {
    binary: true,
  });
  return res;
}
