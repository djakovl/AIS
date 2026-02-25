/*
  Базовый HTTP-клиент API.
  Добавляет X-User-Id, X-Request-Id, парсит ответы {success, data/error}.
*/

import { API_BASE_URL } from '../config.js';

const UNAUTHORIZED_MESSAGES = {
  noUserId: 'Не указан X-User-Id. Проверьте настройки демо.',
  unauthorized: 'Не указан X-User-Id. Проверьте настройки демо.',
};

/*
  Generate unique request ID for tracing.
*/
function generateRequestId() {
  return typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : `req-${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
}


 //Parse API response: success/error format.

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

//Build request URL for given path.

function buildUrl(path) {
  const base = API_BASE_URL.replace(/\/$/, '');
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${base}${p}`;
}

/**
 * Base HTTP request with X-User-Id, Content-Type, X-Request-Id.
 * {string} method - HTTP method (GET, POST, DELETE, etc.)
 * {string} path - API path (e.g. '/files/buckets/list')
 * {Object} [options]
 * {string} [options.userId] - Required for most endpoints; omit for /health, getSharedFile
 * {Object} [options.body] - JSON body (ignored if formData is set)
 * {FormData} [options.formData] - For multipart uploads; body is ignored
 * {string} [options.requestId] - Optional X-Request-Id for tracing
 * {Object} [options.signal] - AbortSignal for cancellation
 * {boolean} [options.binary] - If true, return Blob instead of parsing JSON (for downloads)
 * {Promise<{ ok: boolean, data?: any, error?: { code: string, message: string } }>}
 */
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
  // Для FormData не задаём Content-Type — браузер сам добавит multipart boundary

  const fetchOptions = {
    method,
    headers,
    signal,
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

  // Успешный ответ: бинарные данные (скачивание файла)
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
