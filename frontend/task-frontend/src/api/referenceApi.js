// src/api/referenceApi.js
import request from '@/utils/request'

export const referenceApi = {
  // GET /statuses
  getStatuses() {
    return request({
      url: '/statuses',
      method: 'get'
    })
  },
  
  // GET /priorities
  getPriorities() {
    return request({
      url: '/priorities',
      method: 'get'
    })
  }
}