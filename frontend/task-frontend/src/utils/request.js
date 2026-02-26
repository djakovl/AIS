// src/utils/request.js
import axios from 'axios'

const request = axios.create({
  baseURL: 'https://185.135.82.161:8037/tasks',
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
  withCredentials: true
})

request.interceptors.request.use(config => {
  // Get session token from cookie
  const sessionToken = document.cookie
    .split('; ')
    .find(row => row.startsWith('session_token='))
    ?.split('=')[1]
  
  if (sessionToken) {
    config.headers['X-Session-Token'] = sessionToken
  }

  // Get userId from localStorage or sessionStorage
  const userId = localStorage.getItem('userId') || sessionStorage.getItem('userId')
  if (userId) {
    config.headers['X-User-Id'] = userId
  }

  return config
}, error => Promise.reject(error))

request.interceptors.response.use(
  response => response.data,
  error => {
    console.error('❌ API Error:', error)
    
    // Handle 401 Unauthorized - redirect to auth
    if (error.response?.status === 401) {
      window.location.href = '/auth-app/'
    }
    
    return Promise.reject(error)
  }
)

export default request