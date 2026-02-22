// API клиент для работы с бэкендом

const API_BASE_URL = 'http://localhost';

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
            credentials: 'include', // Для отправки cookies
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

        // Сохраняем CSRF токен
        if (data.csrf_token) {
            this.csrfToken = data.csrf_token;
            localStorage.setItem('csrf_token', data.csrf_token);
        }

        // Сохраняем session_id для mobile (на web он в cookie)
        if (data.session_id) {
            localStorage.setItem('session_id', data.session_id);
        }

        return data;
    }

    async logout() {
        await this.request('/auth/logout', {
            method: 'POST',
        });

        // Очищаем токены
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
