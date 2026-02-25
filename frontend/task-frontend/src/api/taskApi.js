// src/api/taskApi.js
import request from '@/utils/request'

export const taskApi = {
  // LIST
  listTasks(params) {
    return request({
      url: '/tasks',
      method: 'get',
      params
    })
  },

  // GET
  getTask(id) {
    return request({
      url: `/tasks/${id}`,
      method: 'get'
    })
  },

  // CREATE
  createTask(data) {
    return request({
      url: '/tasks',
      method: 'post',
      data
    })
  },

  // UPDATE
  updateTask(id, data) {
    return request({
      url: `/tasks/${id}`,
      method: 'put',
      data
    })
  },

  // DELETE
  deleteTask(id) {
    return request({
      url: `/tasks/${id}`,
      method: 'delete'
    })
  }
}