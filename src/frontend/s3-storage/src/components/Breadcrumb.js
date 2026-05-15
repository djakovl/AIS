// Breadcrumb navigation: Bucket > Folder1 > Folder2.
import { getState, setState, subscribe } from '../store.js';
import { performMove, parseDragPayload } from './FileList.js';

export function renderBreadcrumb(container, onNavigate) {
  if (!container) return;

  const render = () => {
    const { selectedBucket, currentFolderPath } = getState();
    if (!selectedBucket) {
      container.innerHTML = '';
      return;
    }

    const items = [
      { id: null, name: selectedBucket.name, isBucket: true },
      ...currentFolderPath,
    ];

    container.innerHTML = `
      <nav class="breadcrumb">
        ${items.map((item, i) => {
          const isLast = i === items.length - 1;
          return `
            ${i > 0 ? '<span class="breadcrumb-sep">›</span>' : ''}
            <span class="breadcrumb-item ${isLast ? 'current' : ''}" 
                  data-folder-id="${item.id || ''}" 
                  data-is-bucket="${item.isBucket ? '1' : '0'}">
              ${escapeHtml(item.name)}
            </span>
          `;
        }).join('')}
      </nav>
    `;

    container.querySelectorAll('.breadcrumb-item:not(.current)').forEach((el) => {
      el.addEventListener('click', () => {
        const folderId = el.dataset.folderId || null;
        const isBucket = el.dataset.isBucket === '1';
        if (isBucket) {
          setState({ currentFolderId: null, currentFolderPath: [] });
        } else if (folderId) {
          const idx = items.findIndex((it) => it.id === folderId);
          const newPath = idx >= 0 ? items.slice(1, idx + 1) : [];
          setState({ currentFolderId: folderId, currentFolderPath: newPath });
        }
        onNavigate?.();
      });
    });

    // Drop target: root (first item = bucket name)
    const rootItem = container.querySelector('.breadcrumb-item[data-is-bucket="1"]');
    if (rootItem) {
      rootItem.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        rootItem.classList.add('breadcrumb-root-drop-target');
      });
      rootItem.addEventListener('dragleave', (e) => {
        if (e.relatedTarget && rootItem.contains(e.relatedTarget)) return;
        rootItem.classList.remove('breadcrumb-root-drop-target');
      });
      rootItem.addEventListener('drop', (e) => {
        e.preventDefault();
        rootItem.classList.remove('breadcrumb-root-drop-target');
        const payload = parseDragPayload(e.dataTransfer);
        if (!payload) return;
        performMove(payload.fileId, null, onNavigate);
      });
    }
  };

  subscribe(render);
  render();
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
