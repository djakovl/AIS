/*
  Базовый HTTP-клиент API.
  Добавляет X-User-Id, X-Request-Id, X-CSRF-Token (из куки), credentials: include.
*/

import { API_BASE_URL } from '../config.js';

const UNAUTHORIZED_MESSAGES = {
  noUserId: 'Не указан X-User-Id. Проверьте настройки демо.',
  unauthorized: 'Не указан X-User-Id. Проверьте настройки демо.',
};

const CSRF_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

function generateRequestId() {
  return typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : `req-${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
}

function getCookie(name) {
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) return parts.pop().split(';').shift();
  return null;
}

function parseResponse(json) {
  if (json?.success === true) {
    return { ok: true, data: json.data };
  }
  if (json?.success === false && json?.error) {
    return {
      ok: false,
      error: {
        code: json.error.code || 'UNKNOWN',
        message: json.error.message || 'Unknown error',
      },
    };
  }
  return {
    ok: false,
    error: { code: 'INVALID_RESPONSE', message: 'Invalid API response format' },
  };
}

function buildUrl(path) {
  const base = API_BASE_URL.replace(/\/$/, '');
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${base}${p}`;
}

export async function request(method, path, options = {}) {
  const {
    userId,
    body,
    formData,
    requestId: reqId,
    signal,
  } = options;

  const headers = {};

  if (userId) {
    headers['X-User-Id'] = userId;
  }

  const rid = reqId ?? generateRequestId();
  headers['X-Request-Id'] = rid;

  if (!formData) {
    headers['Content-Type'] = 'application/json';
  }

  // Автоматически читаем CSRF токен из куки для мутирующих запросов
  if (CSRF_METHODS.has(method)) {
    const csrfToken = getCookie('csrf_token');
    if (csrfToken) {
      headers['X-CSRF-Token'] = csrfToken;
    }
  }

  const fetchOptions = {
    method,
    headers,
    signal,
    credentials: 'include', // отправляем session_id куки
  };

  if (formData) {
    fetchOptions.body = formData;
  } else if (body !== undefined && body !== null) {
    fetchOptions.body = JSON.stringify(body);
  }

  const url = buildUrl(path);
  let response;
  try {
    response = await fetch(url, fetchOptions);
  } catch (e) {
    const msg = e?.message || 'Network request failed';
    const isCors = /cors|fetch|cross-origin|blocked/i.test(msg) || msg === 'Failed to fetch';
    return {
      ok: false,
      error: {
        code: isCors ? 'CORS_ERROR' : 'NETWORK_ERROR',
        message: 'Проверьте CORS на S3',
      },
    };
  }

  const contentType = response.headers.get('Content-Type') ?? '';
  const isJson = contentType.includes('application/json');

  if (!response.ok) {
    let errMessage = `HTTP ${response.status}`;
    if (response.status === 401) {
      errMessage = userId
        ? UNAUTHORIZED_MESSAGES.unauthorized
        : UNAUTHORIZED_MESSAGES.noUserId;
    } else if (isJson) {
      try {
        const errJson = await response.json();
        if (errJson?.error?.message) {
          errMessage = errJson.error.message;
        }
      } catch (_) {}
    }
    return {
      ok: false,
      error: {
        code: response.status === 401 ? 'UNAUTHORIZED' : 'HTTP_ERROR',
        message: errMessage,
      },
    };
  }

  if (options.binary || !isJson) {
    const blob = await response.blob();
    return { ok: true, data: blob };
  }

  try {
    const json = await response.json();
    return parseResponse(json);
  } catch (e) {
    return {
      ok: false,
      error: {
        code: 'PARSE_ERROR',
        message: e?.message || 'Failed to parse response',
      },
    };
  }
}
