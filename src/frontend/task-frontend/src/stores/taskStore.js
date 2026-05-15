// src/stores/taskStore.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { taskApi } from '@/api/taskApi'

export const useTaskStore = defineStore('tasks', () => {
  const tasks = ref([])
  const currentTask = ref(null)
  const loading = ref(false)
  const filters = ref({
    status_id: null,
    priority_id: null,
    search: '',
    is_completed: null
  })

  const filteredTasks = computed(() => tasks.value)

  async function fetchTasks() {
    loading.value = true
    try {
      const params = {
        ...filters.value,
        page: 1,
        limit: 50
      }
      
      Object.keys(params).forEach(key => {
        if (params[key] === null || params[key] === '') {
          delete params[key]
        }
      })

      const response = await taskApi.listTasks(params)
      // API возвращает { success: true, data: [...] }
      tasks.value = response.data || []
    } catch (error) {
      console.error('Failed to fetch tasks:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  async function fetchTaskById(id) {
    loading.value = true
    try {
      const response = await taskApi.getTask(id)
      currentTask.value = response.data
      return response.data
    } catch (error) {
      console.error('Failed to fetch task:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  async function createTask(taskData) {
    try {
      const response = await taskApi.createTask(taskData)
      await fetchTasks()
      return response.data
    } catch (error) {
      console.error('Failed to create task:', error)
      throw error
    }
  }

  async function updateTask(id, taskData) {
    try {
      const response = await taskApi.updateTask(id, taskData)
      await fetchTasks()
      if (currentTask.value?.id === id) {
        await fetchTaskById(id)
      }
      return response.data
    } catch (error) {
      console.error('Failed to update task:', error)
      throw error
    }
  }

  async function deleteTask(id) {
    try {
      await taskApi.deleteTask(id)
      await fetchTasks()
    } catch (error) {
      console.error('Failed to delete task:', error)
      throw error
    }
  }

  function setFilter(key, value) {
    filters.value[key] = value
  }

  function clearFilters() {
    filters.value = {
      status_id: null,
      priority_id: null,
      search: '',
      is_completed: null
    }
  }

  return {
    tasks,
    currentTask,
    loading,
    filters,
    filteredTasks,
    fetchTasks,
    fetchTaskById,
    createTask,
    updateTask,
    deleteTask,
    setFilter,
    clearFilters
  }
})