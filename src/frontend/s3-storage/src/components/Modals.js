// Modals: create bucket, create folder, delete confirm, share (URL + copy), move.

import {
  createBucket,
  createFolder,
  deleteFile,
  deleteBucket,
  createShareLink,
  moveFile,
  listFiles,
} from '../api/s3.js';
import { API_BASE_URL } from '../config.js';
import { getState, setState, getUserId } from '../store.js';

let toastFn = () => {};

export function setToast(fn) {
  toastFn = fn;
}

function showToast(msg, type) {
  toastFn(msg, type);
}

export function initModals(onRefresh) {
  window.addEventListener('modal:create-bucket', () => openCreateBucketModal(onRefresh));
  window.addEventListener('modal:create-folder', () => openCreateFolderModal(onRefresh));
  window.addEventListener('modal:upload', () => openUploadModal(onRefresh));
  window.addEventListener('modal:delete', (e) => openDeleteModal(e.detail, onRefresh));
  window.addEventListener('modal:delete-bucket', (e) => openDeleteBucketModal(e.detail, onRefresh));
  window.addEventListener('modal:share', (e) => openShareModal(e.detail, onRefresh));
  window.addEventListener('modal:move', (e) => openMoveModal(e.detail, onRefresh));
}

function closeModal() {
  document.getElementById('modal-overlay')?.remove();
}

function renderOverlay(innerHtml, onClickBackdrop = true) {
  const existing = document.getElementById('modal-overlay');
  if (existing) existing.remove();

  const overlay = document.createElement('div');
  overlay.id = 'modal-overlay';
  overlay.className = 'modal-overlay';
  overlay.innerHTML = innerHtml;

  if (onClickBackdrop) {
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) closeModal();
    });
  }

  overlay.querySelector('[data-close]')?.addEventListener('click', closeModal);
  document.body.appendChild(overlay);
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text ?? '';
  return div.innerHTML;
}

//Create Bucket
function openCreateBucketModal(onRefresh) {
  const html = `
    <div class="modal" onclick="event.stopPropagation()">
      <div class="modal-header">Создать бакет</div>
      <div class="modal-body">
        <div class="form-group">
          <label for="bucket-name">Название</label>
          <input id="bucket-name" type="text" placeholder="Мой бакет" required />
        </div>
        <div class="form-group">
          <label for="bucket-desc">Описание (необязательно)</label>
          <textarea id="bucket-desc" placeholder="Описание бакета" rows="2"></textarea>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-close>Отмена</button>
        <button class="btn btn-primary" id="btn-create-bucket-submit">Создать</button>
      </div>
    </div>
  `;
  renderOverlay(html);

  document.getElementById('btn-create-bucket-submit')?.addEventListener('click', async () => {
    const name = document.getElementById('bucket-name')?.value?.trim();
    const description = document.getElementById('bucket-desc')?.value?.trim() || undefined;
    if (!name) {
      showToast('Введите название бакета', 'error');
      return;
    }
    const res = await createBucket(getUserId(), { name, description });
    if (!res.ok) {
      showToast(res.error?.message || 'Ошибка создания бакета', 'error');
      return;
    }
    closeModal();
    showToast('Бакет создан', 'success');
    onRefresh?.();
  });
}

//Create Folder
function openCreateFolderModal(onRefresh) {
  const { selectedBucketId } = getState();
  if (!selectedBucketId) {
    showToast('Сначала выберите бакет', 'error');
    return;
  }
  const { currentFolderId } = getState();

  const html = `
    <div class="modal" onclick="event.stopPropagation()">
      <div class="modal-header">Создать папку</div>
      <div class="modal-body">
        <div class="form-group">
          <label for="folder-name">Название папки</label>
          <input id="folder-name" type="text" placeholder="Новая папка" required />
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-close>Отмена</button>
        <button class="btn btn-primary" id="btn-create-folder-submit">Создать</button>
      </div>
    </div>
  `;
  renderOverlay(html);

  document.getElementById('btn-create-folder-submit')?.addEventListener('click', async () => {
    const name = document.getElementById('folder-name')?.value?.trim();
    if (!name) {
      showToast('Введите название папки', 'error');
      return;
    }
    const res = await createFolder(getUserId(), {
      bucketId: selectedBucketId,
      parentFolderId: currentFolderId || undefined,
      name,
    });
    if (!res.ok) {
      showToast(res.error?.message || 'Ошибка создания папки', 'error');
      return;
    }
    closeModal();
    showToast('Папка создана', 'success');
    onRefresh?.();
  });
}

// Upload (delegates to Uploader)
function openUploadModal(onRefresh) {
  const { selectedBucketId } = getState();
  if (!selectedBucketId) {
    showToast('Сначала выберите бакет', 'error');
    return;
  }
  const { currentFolderId } = getState();

  const html = `
    <div class="modal" onclick="event.stopPropagation()">
      <div class="modal-header">Загрузить файл</div>
      <div class="modal-body">
        <div class="form-group">
          <label>Выберите файл</label>
          <input id="upload-file-input" type="file" />
          <div id="upload-status" style="margin-top:8px;font-size:0.9rem;color:#9ca3af;"></div>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-close>Закрыть</button>
        <button class="btn btn-primary" id="btn-upload-submit">Загрузить</button>
      </div>
    </div>
  `;
  renderOverlay(html);

  const input = document.getElementById('upload-file-input');
  const statusEl = document.getElementById('upload-status');

  document.getElementById('btn-upload-submit')?.addEventListener('click', async () => {
    const file = input?.files?.[0];
    if (!file) {
      showToast('Выберите файл', 'error');
      return;
    }
    statusEl.textContent = 'Загрузка...';
    const formData = new FormData();
    formData.append('file', file);
    formData.append('bucket_id', selectedBucketId);
    if (currentFolderId) formData.append('parent_folder_id', currentFolderId);

    const { uploadFile } = await import('../api/s3.js');
    const res = await uploadFile(getUserId(), formData);

    if (!res.ok) {
      statusEl.textContent = res.error?.message || 'Ошибка';
      showToast(res.error?.message || 'Ошибка загрузки', 'error');
      return;
    }
    closeModal();
    showToast('Файл загружен', 'success');
    onRefresh?.();
  });
}

// Delete
function openDeleteModal(detail, onRefresh) {
  const { fileId, name, isFolder } = detail || {};
  if (!fileId) return;

  const folderHint = isFolder
    ? '<p class="delete-folder-hint">Папка должна быть пустой.</p>'
    : '';

  const html = `
    <div class="modal" onclick="event.stopPropagation()">
      <div class="modal-header">Удалить</div>
      <div class="modal-body">
        <p>Удалить «${escapeHtml(name || 'элемент')}»? Это действие нельзя отменить.</p>
        ${folderHint}
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-close>Отмена</button>
        <button class="btn btn-danger" id="btn-delete-confirm">Удалить</button>
      </div>
    </div>
  `;
  renderOverlay(html);

  document.getElementById('btn-delete-confirm')?.addEventListener('click', async () => {
    const res = await deleteFile(getUserId(), fileId);
    if (!res.ok) {
      const msg = res.error?.message || '';
      const ruMsg = /folder is not empty|папка не пуста/i.test(msg)
        ? 'Папка не пуста. Сначала удалите или переместите содержимое.'
        : msg || 'Ошибка удаления';
      showToast(ruMsg, 'error');
      return;
    }
    closeModal();
    showToast('Удалено', 'success');
    onRefresh?.();
  });
}

//Delete Bucket
function openDeleteBucketModal(detail, onRefresh) {
  const { bucketId, name } = detail || {};
  if (!bucketId) return;

  const html = `
    <div class="modal" onclick="event.stopPropagation()">
      <div class="modal-header">Удалить бакет</div>
      <div class="modal-body">
        <p>Удалить бакет «${escapeHtml(name || '')}» и всё его содержимое? Это действие нельзя отменить.</p>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-close>Отмена</button>
        <button class="btn btn-danger" id="btn-delete-bucket-confirm">Удалить</button>
      </div>
    </div>
  `;
  renderOverlay(html);

  document.getElementById('btn-delete-bucket-confirm')?.addEventListener('click', async () => {
    const res = await deleteBucket(getUserId(), bucketId);
    if (!res.ok) {
      showToast(res.error?.message || 'Ошибка удаления бакета', 'error');
      return;
    }
    closeModal();
    showToast('Бакет удалён', 'success');
    setState({ selectedBucketId: null, selectedBucket: null, currentFolderId: null, currentFolderPath: [] });
    onRefresh?.();
  });
}

//Share
function openShareModal(detail, onRefresh) {
  const { fileId } = detail || {};
  if (!fileId) return;

  const html = `
    <div class="modal" onclick="event.stopPropagation()">
      <div class="modal-header">Поделиться файлом</div>
      <div class="modal-body">
        <div id="share-form">
          <div class="form-group">
            <label for="share-max-downloads">Макс. скачиваний</label>
            <input id="share-max-downloads" type="number" min="1" placeholder="Неограниченно" />
          </div>
          <div class="form-group">
            <label for="share-expires">Срок действия ссылки</label>
            <select id="share-expires">
              <option value="">Без ограничения</option>
              <option value="1h">1 час</option>
              <option value="24h">24 часа</option>
              <option value="7d">7 дней</option>
              <option value="30d">30 дней</option>
            </select>
          </div>
        </div>
        <div id="share-loading" style="display:none;">Создание ссылки...</div>
        <div id="share-result" style="display:none;">
          <p>Ссылка для скачивания:</p>
          <div class="share-url-box">
            <input id="share-url" type="text" readonly />
            <button class="btn btn-primary" id="btn-copy-share">Копировать</button>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-close>Закрыть</button>
        <button class="btn btn-primary" id="btn-share-create">Создать ссылку</button>
      </div>
    </div>
  `;
  renderOverlay(html);

  function computeExpiresAt(value) {
    if (!value) return undefined;
    const now = new Date();
    switch (value) {
      case '1h':
        now.setHours(now.getHours() + 1);
        break;
      case '24h':
        now.setHours(now.getHours() + 24);
        break;
      case '7d':
        now.setDate(now.getDate() + 7);
        break;
      case '30d':
        now.setDate(now.getDate() + 30);
        break;
      default:
        return undefined;
    }
    return now.toISOString();
  }

  document.getElementById('btn-share-create')?.addEventListener('click', async () => {
    const formEl = document.getElementById('share-form');
    const loadingEl = document.getElementById('share-loading');
    const resultEl = document.getElementById('share-result');
    formEl.style.display = 'none';
    loadingEl.style.display = 'block';
    loadingEl.style.color = '';

    const maxDownloadsVal = document.getElementById('share-max-downloads')?.value?.trim();
    const maxDownloads = maxDownloadsVal ? parseInt(maxDownloadsVal, 10) : undefined;
    if (maxDownloads !== undefined && (isNaN(maxDownloads) || maxDownloads < 1)) {
      loadingEl.style.display = 'none';
      formEl.style.display = 'block';
      showToast('Макс. скачиваний должно быть больше 0', 'error');
      return;
    }

    const expiresVal = document.getElementById('share-expires')?.value;
    const expiresAt = computeExpiresAt(expiresVal);

    const params = { fileId };
    if (expiresAt) params.expiresAt = expiresAt;
    if (maxDownloads && maxDownloads > 0) params.maxDownloads = maxDownloads;

    const res = await createShareLink(getUserId(), params);
    const urlInput = document.getElementById('share-url');
    const base = API_BASE_URL.replace(/\/$/, '');
    const sharedPath = `/files/shared/`;

    if (!res.ok) {
      loadingEl.textContent = res.error?.message || 'Ошибка создания ссылки';
      loadingEl.style.color = '#f87171';
      return;
    }
    const token = res.data?.token;
    const shareUrl = token ? `${base}${sharedPath}${encodeURIComponent(token)}` : '';
    loadingEl.style.display = 'none';
    resultEl.style.display = 'block';
    const createBtn = document.getElementById('btn-share-create');
    if (createBtn) createBtn.style.display = 'none';
    if (urlInput) urlInput.value = shareUrl;

    document.getElementById('btn-copy-share')?.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(shareUrl);
        showToast('Ссылка скопирована', 'success');
      } catch {
        showToast('Не удалось скопировать', 'error');
      }
    });
  });
}

//Move: recursively load folder tree
async function fetchFolderTree(userId, bucketId, parentId, excludeId, depth = 0) {
  const res = await listFiles(userId, {
    bucketId,
    parentFolderId: parentId || undefined,
  });
  if (!res.ok) return [];
  const items = res.data?.files || [];
  const folders = items.filter((f) => f.isFolder && f.id !== excludeId);
  const result = [];
  for (const f of folders) {
    result.push({ value: f.id, label: f.name, depth });
    const children = await fetchFolderTree(userId, bucketId, f.id, excludeId, depth + 1);
    result.push(...children);
  }
  return result;
}

// Move
async function openMoveModal(detail, onRefresh) {
  const { fileId, isFolder } = detail || {};
  if (!fileId) return;

  const userId = getUserId()?.trim();
  if (!userId) {
    showToast('Введите User ID', 'error');
    return;
  }

  const { buckets, selectedBucketId } = getState();
  if (!selectedBucketId) {
    showToast('Выберите бакет', 'error');
    return;
  }

  const html = `
    <div class="modal modal-move" onclick="event.stopPropagation()">
      <div class="modal-header">Переместить</div>
      <div class="modal-body">
        <div id="move-loading" class="move-loading">Загрузка структуры папок...</div>
        <div id="move-content" style="display:none;">
          <div class="form-group">
            <label>Куда переместить</label>
            <select id="move-target" class="move-select"></select>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-close>Отмена</button>
        <button class="btn btn-primary" id="btn-move-confirm" disabled>Переместить</button>
      </div>
    </div>
  `;
  renderOverlay(html);

  const loadingEl = document.getElementById('move-loading');
  const contentEl = document.getElementById('move-content');
  const selectEl = document.getElementById('move-target');
  const btnEl = document.getElementById('btn-move-confirm');

  const options = [{ value: 'root', label: '📁 Корень бакета', depth: 0 }];

  try {
    const excludeId = isFolder ? fileId : null;
    const tree = await fetchFolderTree(userId, selectedBucketId, null, excludeId);
    const indent = (n) => (n > 0 ? '  '.repeat(n) + '↳ ' : '');
    tree.forEach((o) => {
      options.push({
        value: o.value,
        label: indent(o.depth) + (o.depth > 0 ? '' : '📁 ') + o.label,
      });
    });

    if (!isFolder) {
      const otherBuckets = buckets.filter((b) => b.id !== selectedBucketId);
      otherBuckets.forEach((b) => {
        options.push({ value: `bucket:${b.id}`, label: `📦 Корень: ${b.name}` });
      });
    }

    selectEl.innerHTML = options
      .map((o) => `<option value="${o.value}">${escapeHtml(o.label)}</option>`)
      .join('');
  } catch {
    showToast('Ошибка загрузки папок', 'error');
    closeModal();
    return;
  }

  loadingEl.style.display = 'none';
  contentEl.style.display = 'block';
  btnEl.disabled = false;

  btnEl?.addEventListener('click', async () => {
    const val = selectEl?.value;
    const body = { fileId };

    if (val === 'root') {
      body.newParentFolderId = null;
    } else if (val.startsWith('bucket:')) {
      body.newBucketId = val.slice(7);
      body.newParentFolderId = null;
    } else {
      body.newParentFolderId = val;
    }

    const res = await moveFile(userId, body);
    if (!res.ok) {
      showToast(res.error?.message || 'Ошибка перемещения', 'error');
      return;
    }
    closeModal();
    showToast('Перемещено', 'success');
    onRefresh?.();
  });
}
