// Главная логика приложения

class AuthApp {
    constructor() {
        this.loginForm = document.getElementById('loginFormElement');
        this.registerForm = document.getElementById('registerFormElement');
        this.logoutBtn = document.getElementById('logoutBtn');

        this.loginSection = document.getElementById('loginForm');
        this.registerSection = document.getElementById('registerForm');
        this.serviceSelector = document.getElementById('serviceSelector');

        this.showLoginBtn = document.getElementById('showLogin');
        this.showRegisterBtn = document.getElementById('showRegister');

        this.init();
    }

    init() {
        // Переключение между формами
        this.showLoginBtn.addEventListener('click', (e) => {
            e.preventDefault();
            this.showLogin();
        });

        this.showRegisterBtn.addEventListener('click', (e) => {
            e.preventDefault();
            this.showRegister();
        });

        // Обработчики форм
        this.loginForm.addEventListener('submit', (e) => this.handleLogin(e));
        this.registerForm.addEventListener('submit', (e) => this.handleRegister(e));
        this.logoutBtn.addEventListener('click', () => this.handleLogout());

        // Проверяем, залогинен ли пользователь
        this.checkAuth();
    }

    async checkAuth() {
        const csrfToken = localStorage.getItem('csrf_token');
        if (csrfToken) {
            try {
                await this.loadProfile();
            } catch (error) {
                this.showLogin();
            }
        }
    }

    showLogin() {
        this.loginSection.classList.remove('hidden');
        this.registerSection.classList.add('hidden');
        this.serviceSelector.classList.add('hidden');
    }

    showRegister() {
        this.loginSection.classList.add('hidden');
        this.registerSection.classList.remove('hidden');
        this.serviceSelector.classList.add('hidden');
    }

    showServiceSelector() {
        this.loginSection.classList.add('hidden');
        this.registerSection.classList.add('hidden');
        this.serviceSelector.classList.remove('hidden');
    }

    async handleRegister(e) {
        e.preventDefault();

        const formData = new FormData(this.registerForm);
        const data = Object.fromEntries(formData);

        // Проверка совпадения паролей
        if (data.password !== data.password_confirm) {
            this.showNotification('Пароли не совпадают', 'error');
            return;
        }

        delete data.password_confirm;

        try {
            await api.register(data);
            this.showNotification('Регистрация успешна! Теперь войдите в систему', 'success');
            this.showLogin();
            this.registerForm.reset();
        } catch (error) {
            this.showNotification(error.message, 'error');
        }
    }

    async handleLogin(e) {
        e.preventDefault();

        const formData = new FormData(this.loginForm);
        const data = Object.fromEntries(formData);

        try {
            const response = await api.login(data);
            this.showNotification(`Добро пожаловать, ${response.user.username}!`, 'success');
            await this.loadProfile();
        } catch (error) {
            this.showNotification(error.message, 'error');
        }
    }

    async handleLogout() {
        try {
            await api.logout();
            this.showNotification('Вы вышли из системы', 'success');
            this.showLogin();
        } catch (error) {
            this.showNotification(error.message, 'error');
        }
    }

    async loadProfile() {
        try {
            const user = await api.getProfile();
            this.displayProfile(user);
            this.showServiceSelector();
        } catch (error) {
            throw error;
        }
    }

    displayProfile(user) {
        document.getElementById('profileEmail').textContent = user.email;
        document.getElementById('profileUsername').textContent = user.username;
    }

    showNotification(message, type = 'success') {
        const notification = document.getElementById('notification');
        notification.textContent = message;
        notification.className = `notification ${type}`;
        notification.classList.remove('hidden');

        setTimeout(() => {
            notification.classList.add('hidden');
        }, 4000);
    }
}

// Запускаем приложение
document.addEventListener('DOMContentLoaded', () => {
    new AuthApp();
});
