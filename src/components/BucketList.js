//Left panel: list of buckets, create bucket button.
import { listBuckets } from '../api/s3.js';
import { getState, setState, getUserId, subscribe } from '../store.js';
import { loadBucketOrder, saveBucketOrder } from '../bucketOrder.js';

let draggedBucketId = null;

export function renderBucketList(container, onRefresh) {
  if (!container) return;

  const render = () => {
    const { buckets, selectedBucketId, loadingBuckets, error, errorCode, userId } = getState();

    let emptyHint = '';
    if (!userId || !userId.trim()) {
      emptyHint = '<div class="state-hint">Введите User ID для демо</div>';
    }

    let errorBlock = '';
    if (error && !loadingBuckets) {
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
      <div class="panel-left">
        <div class="panel-left-header">
          <span>Бакеты</span>
          <button class="btn btn-primary btn-sm" id="btn-create-bucket" type="button" ${!userId?.trim() ? 'disabled' : ''}>
            + Создать
          </button>
        </div>
        <div class="bucket-list">
          ${emptyHint}
          ${loadingBuckets ? '<div class="state-loading">Загрузка...</div>' : ''}
          ${errorBlock}
          ${!emptyHint && !error && !loadingBuckets && buckets.length === 0 ? '<div class="state-empty">Нет бакетов</div>' : ''}
          ${!emptyHint && !loadingBuckets && !error ? buckets.map((b) => `
            <div class="bucket-item ${b.id === selectedBucketId ? 'active' : ''}" data-bucket-id="${b.id}" tabindex="0">
              <span class="bucket-drag-handle" draggable="true" aria-label="Переместить" tabindex="-1" role="button">⋮⋮</span>
              <span class="icon">📦</span>
              <span class="bucket-item-name">${escapeHtml(b.name)}</span>
              <button class="bucket-delete-btn" data-bucket-id="${b.id}" data-bucket-name="${escapeHtml(b.name)}" aria-label="Удалить бакет" type="button">🗑️</button>
            </div>
          `).join('') : ''}
        </div>
      </div>
    `;

    container.querySelectorAll('.bucket-item').forEach((el) => {
      el.addEventListener('click', (e) => {
        if (e.target.closest('.bucket-drag-handle') || e.target.closest('.bucket-delete-btn')) return;
        const id = el.dataset.bucketId;
        if (id) {
          setState({
            selectedBucketId: id,
            selectedBucket: buckets.find((b) => b.id === id) || null,
            currentFolderId: null,
            currentFolderPath: [],
          });
          onRefresh?.();
        }
      });

      el.addEventListener('keydown', (e) => {
        if (e.ctrlKey && (e.key === 'ArrowUp' || e.key === 'ArrowDown')) {
          e.preventDefault();
          const state = getState();
          const currentBuckets = state.buckets;
          const uid = getUserId()?.trim() ?? '';
          if (!uid) return;
          const idx = currentBuckets.findIndex((b) => b.id === el.dataset.bucketId);
          if (idx === -1) return;
          const newIdx = e.key === 'ArrowUp' ? idx - 1 : idx + 1;
          if (newIdx < 0 || newIdx >= currentBuckets.length) return;
          const reordered = [...currentBuckets];
          [reordered[idx], reordered[newIdx]] = [reordered[newIdx], reordered[idx]];
          setState({ buckets: reordered });
          saveBucketOrder(uid, reordered.map((b) => b.id));
          setTimeout(() => container.querySelector(`[data-bucket-id="${reordered[newIdx].id}"]`)?.focus(), 0);
        }
      });
    });

    container.querySelectorAll('.bucket-delete-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const bucketId = btn.dataset.bucketId;
        const name = btn.dataset.bucketName ?? '';
        if (bucketId) {
          window.dispatchEvent(new CustomEvent('modal:delete-bucket', {
            detail: { bucketId, name },
          }));
        }
      });
    });

    container.querySelectorAll('.bucket-drag-handle').forEach((handle) => {
      handle.addEventListener('click', (e) => e.stopPropagation());
      handle.addEventListener('mousedown', (e) => e.stopPropagation());

      handle.addEventListener('dragstart', (e) => {
        const item = handle.closest('.bucket-item');
        if (!item) return;
        draggedBucketId = item.dataset.bucketId;
        e.dataTransfer.setData('text/plain', item.dataset.bucketId);
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setDragImage(item, 0, 0);
        item.classList.add('bucket-item-dragging');
      });

      handle.addEventListener('dragend', () => {
        draggedBucketId = null;
        container.querySelectorAll('.bucket-item-dragging').forEach((i) => i.classList.remove('bucket-item-dragging'));
        container.querySelectorAll('.bucket-item-drop-target').forEach((i) => i.classList.remove('bucket-item-drop-target'));
      });
    });

    container.querySelectorAll('.bucket-item').forEach((el) => {
      el.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        container.querySelectorAll('.bucket-item-drop-target').forEach((i) => i.classList.remove('bucket-item-drop-target'));
        if (draggedBucketId && draggedBucketId !== el.dataset.bucketId) {
          el.classList.add('bucket-item-drop-target');
        }
      });

      el.addEventListener('dragleave', (e) => {
        if (e.relatedTarget && el.contains(e.relatedTarget)) return;
        el.classList.remove('bucket-item-drop-target');
      });

      el.addEventListener('drop', (e) => {
        e.preventDefault();
        el.classList.remove('bucket-item-drop-target');
        const sourceId = e.dataTransfer.getData('text/plain');
        if (!sourceId || sourceId === el.dataset.bucketId) return;
        const state = getState();
        const currentBuckets = state.buckets;
        const uid = getUserId()?.trim() ?? '';
        if (!uid) return;
        const sourceIdx = currentBuckets.findIndex((b) => b.id === sourceId);
        const targetIdx = currentBuckets.findIndex((b) => b.id === el.dataset.bucketId);
        if (sourceIdx === -1 || targetIdx === -1) return;
        const reordered = [...currentBuckets];
        const [removed] = reordered.splice(sourceIdx, 1);
        reordered.splice(targetIdx, 0, removed);
        setState({ buckets: reordered });
        saveBucketOrder(uid, reordered.map((b) => b.id));
      });
    });

    container.querySelector('#btn-create-bucket')?.addEventListener('click', () => {
      window.dispatchEvent(new CustomEvent('modal:create-bucket'));
    });
  };

  subscribe(render);
  render();
}

export async function fetchBuckets() {
  const userId = getUserId()?.trim() ?? '';
  if (!userId) {
    setState({
      buckets: [],
      loadingBuckets: false,
      error: null,
      errorCode: null,
    });
    return;
  }
  setState({ loadingBuckets: true, error: null, errorCode: null });
  const res = await listBuckets(userId);
  setState({ loadingBuckets: false });

  if (!res.ok) {
    setState({
      buckets: [],
      error: res.error?.message || 'Ошибка загрузки бакетов',
      errorCode: res.error?.code || null,
    });
    return;
  }

  const buckets = res.data?.buckets || [];
  const order = loadBucketOrder(userId);

  let sorted = buckets;
  if (order && order.length > 0) {
    const orderMap = new Map(order.map((id, idx) => [id, idx]));
    sorted = [...buckets].sort((a, b) => {
      const ai = orderMap.has(a.id) ? orderMap.get(a.id) : Infinity;
      const bi = orderMap.has(b.id) ? orderMap.get(b.id) : Infinity;
      return ai - bi;
    });
  }

  const cleanedOrder = (order || []).filter((id) => buckets.some((b) => b.id === id));
  const newIds = buckets.filter((b) => !(order || []).includes(b.id)).map((b) => b.id);
  const finalOrder = [...cleanedOrder, ...newIds];
  if (newIds.length > 0 || cleanedOrder.length !== (order || []).length) {
    saveBucketOrder(userId, finalOrder);
  }

  setState({
    buckets: sorted,
    error: null,
    errorCode: null,
  });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
