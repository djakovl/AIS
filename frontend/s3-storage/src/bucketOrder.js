// Persist and load bucket order per user via localStorage.
const STORAGE_KEY_PREFIX = 's3-bucket-order-';

/*
 Load bucket order from localStorage.
 {string} userId - User UUID
 {string[]|null} Array of bucket ids, or null if not stored/empty userId
 */
export function loadBucketOrder(userId) {
  const id = String(userId ?? '').trim();
  if (!id) return null;
  try {
    const raw = localStorage.getItem(STORAGE_KEY_PREFIX + id);
    if (raw == null) return null;
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr : null;
  } catch {
    return null;
  }
}

/**
 * Save bucket order to localStorage.
 {string} userId - User UUID
 {string[]} ids - Array of bucket ids
 */
export function saveBucketOrder(userId, ids) {
  const id = String(userId ?? '').trim();
  if (!id) return;
  if (!Array.isArray(ids)) return;
  try {
    localStorage.setItem(STORAGE_KEY_PREFIX + id, JSON.stringify(ids));
  } catch {
    // ignore quota/serialization errors
  }
}
