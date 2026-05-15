// API клиент для работы с бэкендом

// Пустой базовый URL — запросы идут на тот же хост и порт, что и сам сайт
const API_BASE_URL = '';

class ApiClient {
    constructor(baseUrl) {
        this.baseUrl = baseUrl;
        this.csrfToken = localStorage.getItem('csrf_token') || '';
    }

    async request(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers,
        };

        // Добавляем CSRF токен для POST/PUT/PATCH/DELETE
        if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(options.method)) {
            headers['X-CSRF-Token'] = this.csrfToken;
        }

        const config = {
            ...options,
            headers,
            credentials: 'include',
        };

        try {
            const response = await fetch(url, config);
            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error.message || 'Ошибка сервера');
            }

            return data.data;
        } catch (error) {
            console.error('API Error:', error);
            throw error;
        }
    }

    async register(userData) {
        return this.request('/auth/register', {
            method: 'POST',
            body: JSON.stringify(userData),
        });
    }

    async login(credentials) {
        const data = await this.request('/auth/login', {
            method: 'POST',
            body: JSON.stringify(credentials),
        });

        if (data.csrf_token) {
            this.csrfToken = data.csrf_token;
            localStorage.setItem('csrf_token', data.csrf_token);
        }

        if (data.session_id) {
            localStorage.setItem('session_id', data.session_id);
        }

        return data;
    }

    async logout() {
        await this.request('/auth/logout', {
            method: 'POST',
        });

        this.csrfToken = '';
        localStorage.removeItem('csrf_token');
        localStorage.removeItem('session_id');
    }

    async getProfile() {
        return this.request('/auth/profile', {
            method: 'GET',
        });
    }
}

const api = new ApiClient(API_BASE_URL);
