//Right panel: table of files/folders, create folder, upload, actions.

import { listFiles, downloadFile, moveFile } from '../api/s3.js';
import { getState, setState, getUserId, subscribe } from '../store.js';

let draggedFileId = null;
let moveInProgress = false;

export function renderFileList(container, onRefresh) {
  if (!container) return;

  const render = () => {
    const {
      selectedBucketId,
      files,
      currentFolderId,
      currentFolderPath,
      loadingFiles,
      error,
      errorCode,
    } = getState();

    if (!selectedBucketId) {
      container.innerHTML = '<div class="state-empty">Выберите бакет</div>';
      return;
    }

    let errorBlock = '';
    if (error && !loadingFiles) {
      const updateHint = errorCode === 'UNAUTHORIZED'
        ? '<div class="state-error-hint">Обновите User ID в поле выше.</div>'
        : (errorCode === 'CORS_ERROR' || errorCode === 'NETWORK_ERROR')
          ? '<div class="state-error-hint">Убедитесь, что S3 разрешает origin dev server (5173).</div>'
          : '';
      errorBlock = `
        <div class="state-error">${escapeHtml(error)}</div>
        ${updateHint}
      `;
    }

    container.innerHTML = `
      <div class="file-list-container">
        ${loadingFiles ? '<div class="state-loading">Загрузка...</div>' : ''}
        ${errorBlock}
        ${!loadingFiles && !error && files.length === 0
          ? '<div class="state-empty">Папка пуста</div>'
          : ''}
        ${!loadingFiles && !error && files.length > 0 ? `
          <table class="file-table">
            <colgroup>
              <col class="col-drag">
              <col class="col-name">
              <col class="col-type">
              <col class="col-size">
              <col class="col-date">
              <col class="col-actions">
            </colgroup>
            <thead>
              <tr>
                <th class="file-drag-cell" scope="col" aria-label="Перетащить"><span class="file-drag-handle-header">⋮⋮</span></th>
                <th scope="col">Имя</th>
                <th scope="col">Тип</th>
                <th scope="col">Размер</th>
                <th scope="col">Дата</th>
                <th scope="col">Действия</th>
              </tr>
            </thead>
            <tbody>
              ${files.map((f) => `
                <tr class="file-row" data-id="${f.id}" data-is-folder="${f.isFolder ? '1' : '0'}" data-bucket-id="${selectedBucketId}">
                  <td class="file-drag-cell">
                    <span class="file-drag-handle" draggable="true" aria-label="Переместить" tabindex="-1" role="button">⋮⋮</span>
                  </td>
                  <td>
                    <div class="file-name">
                      <span class="file-icon">${f.isFolder ? '📁' : '📄'}</span>
                      <span>${escapeHtml(f.name)}</span>
                    </div>
                  </td>
                  <td>${f.isFolder ? 'Папка' : (f.mimeType || '—')}</td>
                  <td>${f.isFolder ? '—' : formatSize(f.size)}</td>
                  <td>${formatDate(f.createdAt)}</td>
                  <td>
                    <div class="row-actions">
                      ${!f.isFolder ? `<button class="btn btn-secondary btn-sm btn-download" data-id="${f.id}">Скачать</button>` : ''}
                      ${!f.isFolder ? `<button class="btn btn-secondary btn-sm btn-share" data-id="${f.id}">Поделиться</button>` : ''}
                      <button class="btn btn-secondary btn-sm btn-move" data-id="${f.id}" data-is-folder="${f.isFolder ? '1' : '0'}">Переместить</button>
                      <button class="btn btn-danger btn-sm btn-delete" data-id="${f.id}" data-name="${escapeAttr(f.name)}">Удалить</button>
                    </div>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        ` : ''}
      </div>
    `;

    container.querySelectorAll('tbody tr').forEach((row) => {
      const isFolder = row.dataset.isFolder === '1';
      const id = row.dataset.id;
      row.addEventListener('click', (e) => {
        if (e.target.closest('.row-actions')) return;
        if (isFolder) {
          const f = files.find((x) => x.id === id);
          if (f) {
            setState({
              currentFolderId: f.id,
              currentFolderPath: [...currentFolderPath, { id: f.id, name: f.name }],
            });
            onRefresh?.();
          }
        }
      });
    });

    container.querySelectorAll('.btn-download').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        handleDownload(btn.dataset.id);
      });
    });
    container.querySelectorAll('.btn-share').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        window.dispatchEvent(new CustomEvent('modal:share', { detail: { fileId: btn.dataset.id } }));
      });
    });
    container.querySelectorAll('.btn-move').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        window.dispatchEvent(new CustomEvent('modal:move', {
          detail: { fileId: btn.dataset.id, isFolder: btn.dataset.isFolder === '1' },
        }));
      });
    });
    container.querySelectorAll('.btn-delete').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        window.dispatchEvent(new CustomEvent('modal:delete', {
          detail: { fileId: btn.dataset.id, name: btn.dataset.name, isFolder: btn.dataset.isFolder === '1' },
        }));
      });
    });

    // Drag handle: source DnD
    container.querySelectorAll('.file-drag-handle').forEach((handle) => {
      handle.addEventListener('click', (e) => e.stopPropagation());
      handle.addEventListener('mousedown', (e) => e.stopPropagation());

      handle.addEventListener('dragstart', (e) => {
        const row = handle.closest('.file-row');
        if (!row) return;
        draggedFileId = row.dataset.id;
        const payload = {
          fileId: row.dataset.id,
          isFolder: row.dataset.isFolder === '1',
          bucketId: row.dataset.bucketId,
        };
        e.dataTransfer.setData('application/json', JSON.stringify(payload));
        e.dataTransfer.setData('text/plain', row.dataset.id);
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setDragImage(row, 0, 0);
        row.classList.add('file-row-dragging');
      });

      handle.addEventListener('dragend', () => {
        draggedFileId = null;
        container.querySelectorAll('.file-row-dragging').forEach((r) => r.classList.remove('file-row-dragging'));
        container.querySelectorAll('.file-row-drop-target').forEach((r) => r.classList.remove('file-row-drop-target'));
        const bc = document.querySelector('.breadcrumb');
        if (bc) bc.classList.remove('breadcrumb-root-drop-target');
      });
    });

    // Drop targets: folder rows
    container.querySelectorAll('.file-row[data-is-folder="1"]').forEach((row) => {
      row.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        container.querySelectorAll('.file-row-drop-target').forEach((r) => r.classList.remove('file-row-drop-target'));
        document.querySelectorAll('.breadcrumb-root-drop-target').forEach((el) => el.classList.remove('breadcrumb-root-drop-target'));
        const targetId = row.dataset.id;
        if (draggedFileId && draggedFileId !== targetId) {
          row.classList.add('file-row-drop-target');
        }
      });

      row.addEventListener('dragleave', (e) => {
        if (e.relatedTarget && row.contains(e.relatedTarget)) return;
        row.classList.remove('file-row-drop-target');
      });

      row.addEventListener('drop', (e) => {
        e.preventDefault();
        e.stopPropagation();
        row.classList.remove('file-row-drop-target');
        const payload = parseDragPayload(e.dataTransfer);
        if (!payload || payload.fileId === row.dataset.id) return;
        performMove(payload.fileId, row.dataset.id, onRefresh);
      });
    });

    // Drop target: root (file-list-container)
    const listContainer = container.querySelector('.file-list-container');
    if (listContainer) {
      listContainer.addEventListener('dragover', (e) => {
        if (e.target.closest('.file-row[data-is-folder="1"]')) return;
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        container.querySelectorAll('.file-row-drop-target').forEach((r) => r.classList.remove('file-row-drop-target'));
        const bcFirst = document.querySelector('.breadcrumb-item[data-is-bucket="1"]');
        if (bcFirst && draggedFileId) {
          document.querySelectorAll('.breadcrumb-root-drop-target').forEach((el) => el.classList.remove('breadcrumb-root-drop-target'));
          bcFirst.classList.add('breadcrumb-root-drop-target');
        }
      });

      listContainer.addEventListener('dragleave', (e) => {
        if (e.relatedTarget && listContainer.contains(e.relatedTarget)) return;
        document.querySelectorAll('.breadcrumb-root-drop-target').forEach((el) => el.classList.remove('breadcrumb-root-drop-target'));
      });

      listContainer.addEventListener('drop', (e) => {
        if (e.target.closest('.file-row[data-is-folder="1"]')) return;
        e.preventDefault();
        document.querySelectorAll('.breadcrumb-root-drop-target').forEach((el) => el.classList.remove('breadcrumb-root-drop-target'));
        const payload = parseDragPayload(e.dataTransfer);
        if (!payload) return;
        performMove(payload.fileId, null, onRefresh);
      });
    }
  };

  subscribe(render);
  render();
}

export async function fetchFiles() {
  const { selectedBucketId, currentFolderId } = getState();
  if (!selectedBucketId) return;

  const userId = getUserId()?.trim() ?? '';
  if (!userId) {
    setState({ files: [], loadingFiles: false, error: null, errorCode: null });
    return;
  }

  setState({ loadingFiles: true, error: null, errorCode: null });
  const res = await listFiles(userId, {
    bucketId: selectedBucketId,
    parentFolderId: currentFolderId || undefined,
  });
  setState({ loadingFiles: false });

  if (!res.ok) {
    setState({ files: [], error: res.error?.message || 'Ошибка загрузки файлов', errorCode: res.error?.code || null });
    return;
  }
  setState({ files: res.data?.files || [], error: null, errorCode: null });
}

async function handleDownload(fileId) {
  const res = await downloadFile(getUserId(), fileId);
  if (!res.ok) {
    showToast(res.error?.message || 'Ошибка скачивания', 'error');
    return;
  }
  const file = getState().files.find((f) => f.id === fileId);
  const name = file?.name || 'download';
  const url = URL.createObjectURL(res.data);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}

function formatSize(bytes) {
  if (bytes === 0) return '0 Б';
  const k = 1024;
  const sizes = ['Б', 'КБ', 'МБ', 'ГБ'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
}

function formatDate(s) {
  if (!s) return '—';
  try {
    const d = new Date(s);
    return isNaN(d.getTime()) ? s : d.toLocaleString();
  } catch {
    return s;
  }
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text ?? '';
  return div.innerHTML;
}

function escapeAttr(text) {
  return String(text ?? '').replace(/"/g, '&quot;');
}

export function parseDragPayload(dataTransfer) {
  try {
    const json = dataTransfer.getData('application/json');
    if (json) {
      const p = JSON.parse(json);
      if (p && p.fileId) return p;
    }
    // Don't fallback to text/plain — bucket list also sets it (bucket ID)
    // and we'd incorrectly treat bucket drops as file moves
  } catch {}
  return null;
}

export async function performMove(fileId, newParentFolderId, onRefresh) {
  if (moveInProgress) return;
  const userId = getUserId()?.trim() ?? '';
  if (!userId) {
    showToast('Введите User ID', 'error');
    return;
  }
  const file = getState().files.find((f) => f.id === fileId);
  const currentParent = file?.parentFolderId || null;
  const targetParent = newParentFolderId || null;
  if (currentParent === targetParent) return;
  moveInProgress = true;
  try {
    const res = await moveFile(userId, { fileId, newParentFolderId: newParentFolderId || null });
    if (!res.ok) {
      showToast(res.error?.message || 'Ошибка перемещения', 'error');
      return;
    }
    showToast('Перемещено', 'success');
    onRefresh?.();
  } finally {
    moveInProgress = false;
  }
}

let showToastRef;
export function setShowToast(fn) {
  showToastRef = fn;
}
function showToast(msg, type = 'info') {
  showToastRef?.(msg, type);
}
