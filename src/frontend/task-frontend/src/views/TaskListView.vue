<template>
  <div class="task-list-view">
    <header class="page-header">
      <h1>Задачи</h1>
      <button class="btn-add" @click="showCreateModal = true">
        + Новая задача
      </button>
    </header>

    <TaskFilters />
    
    <div v-if="store.loading" class="loading">Загрузка...</div>
    
    <div v-else-if="store.tasks.length === 0" class="empty-state">
      <p>Нет задач</p>
      <button class="btn-add" @click="showCreateModal = true">
        + Создать первую задачу
      </button>
    </div>

    <TaskList 
      v-else
      :tasks="store.tasks"
      @click="viewTask"
      @complete="handleComplete"
    />

    <TaskForm 
      v-if="showCreateModal"
      @close="showCreateModal = false"
      @saved="handleTaskSaved"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useTaskStore } from '@/stores/taskStore'
import TaskFilters from '@/components/TaskFilters.vue'
import TaskList from '@/components/TaskList.vue'
import TaskForm from '@/components/TaskForm.vue'

const router = useRouter()
const store = useTaskStore()
const showCreateModal = ref(false)

onMounted(() => {
  store.fetchTasks()
})

const viewTask = (task) => {
  router.push(`/tasks/${task.id}`)
}

const handleComplete = async (task) => {
  try {
    await store.updateTask(task.id, {
      is_completed: true
    })
  } catch (error) {
    console.error('Failed to complete task:', error)
    alert('Ошибка при завершении задачи')
  }
}

const handleTaskSaved = () => {
  store.fetchTasks()
}
</script>

<style scoped>
.task-list-view {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem 1rem;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.page-header h1 {
  margin: 0;
  font-size: 2rem;
  color: #333;
}

.btn-add {
  padding: 0.75rem 1.5rem;
  background: #2196f3;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  transition: background 0.2s;
}

.btn-add:hover {
  background: #1976d2;
}

.loading, .empty-state {
  text-align: center;
  padding: 3rem;
  color: #999;
}

.empty-state button {
  margin-top: 1rem;
}
</style>