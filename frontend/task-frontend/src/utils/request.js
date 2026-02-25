// src/utils/request.js
import axios from 'axios'

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3003',
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' }
})

request.interceptors.request.use(config => {
  let userId = "3422b448-2460-4fd2-9183-8000de6f8342"
  config.headers['X-User-Id'] = userId
  return config
}, error => Promise.reject(error))

request.interceptors.response.use(
  response => response.data,
  error => {
    console.error('❌ API Error:', error)
    return Promise.reject(error)
  }
)

export default request