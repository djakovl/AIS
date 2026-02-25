// Глобальное состояние приложения. Pub/sub: subscribe() — подписка, setState() — обновление.

export const STORAGE_KEY_USER_ID = 's3-demo-user-id';
const DEFAULT_USER_ID = '00000000-0000-0000-0000-000000000001';

function loadUserId() {
  const stored = localStorage.getItem(STORAGE_KEY_USER_ID);
  return stored !== null ? stored : DEFAULT_USER_ID;
}

const state = {
  userId: loadUserId(),
  buckets: [],
  files: [],
  selectedBucketId: null,
  selectedBucket: null,
  currentFolderId: null,
  currentFolderPath: [],
  loadingBuckets: false,
  loadingFiles: false,
  error: null,
  errorCode: null,
};

// Подписчики: вызываются при каждом setState()
const listeners = new Set();

export function getState() {
  return { ...state };
}

// Обновление состояния и уведомление подписчиков
export function setState(updates) {
  Object.assign(state, updates);
  listeners.forEach((fn) => fn(state));
}

export function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function getUserId() {
  return state.userId;
}

export function setUserId(id) {
  state.userId = id ?? '';
  localStorage.setItem(STORAGE_KEY_USER_ID, state.userId);
  listeners.forEach((fn) => fn(state));
}
