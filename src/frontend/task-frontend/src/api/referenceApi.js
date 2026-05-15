// src/api/referenceApi.js
import request from '@/utils/request'

export const referenceApi = {
  getStatuses() {
    return request({ url: '/tasks/statuses', method: 'get' })
  },
  getPriorities() {
    return request({ url: '/tasks/priorities', method: 'get' })
  }
}
