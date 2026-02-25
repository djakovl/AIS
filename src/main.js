// S3 Storage SPA — бакеты, папки, файлы: загрузка, скачивание, перемещение, удаление, шаринг.

import './styles/main.css';
import './styles/app.css';
import { renderBucketList, fetchBuckets } from './components/BucketList.js';
import { renderFileList, fetchFiles, setShowToast } from './components/FileList.js';
import { renderBreadcrumb } from './components/Breadcrumb.js';
import { initModals, setToast } from './components/Modals.js';
import { getState, subscribe, setUserId } from './store.js';

// Всплывающее уведомление в правом нижнем углу (4 сек)
function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 4000);
}

// Обновление списка бакетов и файлов выбранного бакета
function refresh() {
  fetchBuckets();
  const { selectedBucketId } = getState();
  if (selectedBucketId) {
    fetchFiles();
  }
}

function closeDrawer() {
  document.body.classList.remove('drawer-open');
  const btn = document.getElementById('btn-burger');
  const backdrop = document.getElementById('drawer-backdrop');
  if (btn) btn.setAttribute('aria-expanded', 'false');
  if (backdrop) backdrop.setAttribute('aria-hidden', 'true');
}

function refreshAndCloseDrawer() {
  refresh();
  closeDrawer();
}

// Точка входа: сборка layout, подписка на store, обработчики
document.addEventListener('DOMContentLoaded', () => {
  const app = document.getElementById('app');
  if (!app) return;

  app.innerHTML = `
    <div id="toast-container" class="toast-container"></div>
    <div class="app-header">
      <button class="btn-burger" id="btn-burger" type="button" aria-label="Открыть меню бакетов" aria-expanded="false">☰</button>
      <span class="app-title">S3 Storage</span>
      <!-- Закомментировано: демо-поле User ID (тестовый режим без Gateway)
      <div class="app-header-user">
        <label for="demo-user-id">User ID</label>
        <input id="demo-user-id" type="text" placeholder="00000000-0000-0000-0000-000000000001" title="Тестовый режим: UUID пользователя для подключения к API без Gateway" />
      </div>
      -->
    </div>
    <div class="app-layout">
      <div id="bucket-list-mount"></div>
      <div class="panel-right">
        <div class="panel-right-header">
          <div id="breadcrumb-mount"></div>
          <div class="toolbar">
            <button class="btn btn-primary btn-sm" id="btn-create-folder" type="button">📁 Создать папку</button>
            <button class="btn btn-primary btn-sm" id="btn-upload" type="button">📤 Загрузить файл</button>
            <button class="btn btn-danger btn-sm" id="btn-delete-bucket" type="button" style="visibility:hidden">Удалить бакет</button>
          </div>
        </div>
        <div id="file-list-mount"></div>
      </div>
    </div>
    <div class="drawer-backdrop" id="drawer-backdrop" aria-hidden="true"></div>
  `;

  setToast(showToast);
  setShowToast(showToast);
  initModals(refresh);

  document.getElementById('btn-burger')?.addEventListener('click', () => {
    document.body.classList.toggle('drawer-open');
    const btn = document.getElementById('btn-burger');
    const backdrop = document.getElementById('drawer-backdrop');
    const isOpen = document.body.classList.contains('drawer-open');
    if (btn) btn.setAttribute('aria-expanded', isOpen);
    if (backdrop) backdrop.setAttribute('aria-hidden', !isOpen);
  });
  document.getElementById('drawer-backdrop')?.addEventListener('click', () => {
    closeDrawer();
  });

  renderBucketList(document.getElementById('bucket-list-mount'), refreshAndCloseDrawer);
  renderBreadcrumb(document.getElementById('breadcrumb-mount'), refresh);
  renderFileList(document.getElementById('file-list-mount'), refresh);

  document.getElementById('btn-create-folder')?.addEventListener('click', () => {
    window.dispatchEvent(new CustomEvent('modal:create-folder'));
  });
  document.getElementById('btn-upload')?.addEventListener('click', () => {
    window.dispatchEvent(new CustomEvent('modal:upload'));
  });
  document.getElementById('btn-delete-bucket')?.addEventListener('click', () => {
    const { selectedBucket } = getState();
    if (selectedBucket) {
      window.dispatchEvent(new CustomEvent('modal:delete-bucket', {
        detail: { bucketId: selectedBucket.id, name: selectedBucket.name },
      }));
    } else {
      showToast('Выберите бакет', 'error');
    }
  });

  subscribe((state) => {
    const btn = document.getElementById('btn-delete-bucket');
    if (btn) btn.style.visibility = state.selectedBucketId ? 'visible' : 'hidden';
  });

  // Закомментировано: обработчики поля User ID (тестовый режим без Gateway)
  // const userIdInput = document.getElementById('demo-user-id');
  // if (userIdInput) {
  //   userIdInput.value = getState().userId;
  //   userIdInput.addEventListener('change', () => {
  //     const val = userIdInput.value?.trim() ?? '';
  //     setUserId(val);
  //     refresh();
  //   });
  //   userIdInput.addEventListener('blur', () => {
  //     const val = userIdInput.value?.trim() ?? '';
  //     setUserId(val);
  //     refresh();
  //   });
  // }
  //
  // subscribe((state) => {
  //   const input = document.getElementById('demo-user-id');
  //   if (input && input.value !== state.userId) {
  //     input.value = state.userId;
  //   }
  // });

  refresh();
});
