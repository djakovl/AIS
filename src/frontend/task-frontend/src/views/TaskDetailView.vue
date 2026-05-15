<template>
  <div class="task-detail-view" v-if="task">
    <button class="btn-back" @click="$router.back()">← Назад</button>
    
    <div class="task-header" :style="{ borderLeftColor: task.priority?.color || '#2196f3' }">
      <h1>{{ task.title }}</h1>
      <div class="task-badges">
        <span 
          class="badge priority" 
          :style="{ 
            backgroundColor: task.priority?.color + '20',
            color: task.priority?.color 
          }"
        >
          {{ task.priority?.name || 'Приоритет' }}
        </span>
        <span 
          class="badge status" 
          :style="{ 
            backgroundColor: task.status?.color + '20',
            color: task.status?.color 
          }"
        >
          {{ task.status?.name || 'Статус' }}
        </span>
      </div>
    </div>

    <div class="task-content">
      <section class="section">
        <h3>Описание</h3>
        <p>{{ task.description || 'Нет описания' }}</p>
      </section>

      <section class="section">
        <h3>Детали</h3>
        <div class="details-grid">
          <div class="detail-item">
            <label>Создана</label>
            <value>{{ formatDate(task.created_at) }}</value>
          </div>
          <div class="detail-item" v-if="task.due_date">
            <label>Срок выполнения</label>
            <value :class="{ overdue: isOverdue(task.due_date) }">
              {{ formatDate(task.due_date) }}
            </value>
          </div>
          <div class="detail-item" v-if="task.completed_at">
            <label>Завершена</label>
            <value>{{ formatDate(task.completed_at) }}</value>
          </div>
        </div>
      </section>

      <div class="task-actions">
        <button 
          v-if="!task.is_completed" 
          class="btn-complete"
          @click="completeTask"
        >
          ✓ Завершить задачу
        </button>
        <button class="btn-edit" @click="showEditModal = true">
          ✎ Редактировать
        </button>
        <button class="btn-delete" @click="deleteTask">
          🗑 Удалить
        </button>
      </div>
    </div>

    <TaskForm 
      v-if="showEditModal"
      :task-id="taskId"
      @close="showEditModal = false"
      @saved="handleTaskSaved"
    />
  </div>

  <div v-else class="loading">Загрузка...</div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useTaskStore } from '@/stores/taskStore'
import TaskForm from '@/components/TaskForm.vue'

const route = useRoute()
const router = useRouter()
const store = useTaskStore()
const taskId = route.params.id
const showEditModal = ref(false)

const task = computed(() => store.currentTask)

onMounted(() => {
  store.fetchTaskById(taskId)
})

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleString('ru-RU', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const isOverdue = (dateString) => {
  return new Date(dateString) < new Date()
}

const completeTask = async () => {
  try {
    await store.updateTask(taskId, {
      is_completed: true,
      status_id: 'status-completed-id' // замените на актуальный ID
    })
    await store.fetchTaskById(taskId)
  } catch (error) {
    console.error('Failed to complete task:', error)
    alert('Ошибка при завершении задачи')
  }
}

const deleteTask = async () => {
  if (confirm('Вы уверены, что хотите удалить эту задачу?')) {
    try {
      await store.deleteTask(taskId)
      router.push('/')
    } catch (error) {
      console.error('Failed to delete task:', error)
      alert('Ошибка при удалении задачи')
    }
  }
}

const handleTaskSaved = () => {
  store.fetchTaskById(taskId)
  showEditModal.value = false
}
</script>

<style scoped>
.task-detail-view {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem 1rem;
}

.btn-back {
  background: none;
  border: none;
  color: #2196f3;
  font-size: 1rem;
  cursor: pointer;
  margin-bottom: 1rem;
}

.btn-back:hover {
  text-decoration: underline;
}

.task-header {
  background: white;
  padding: 2rem;
  border-radius: 12px;
  margin-bottom: 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  border-left: 6px solid #2196f3;
}

.task-header h1 {
  margin: 0 0 1rem 0;
  font-size: 2rem;
}

.task-badges {
  display: flex;
  gap: 0.5rem;
}

.badge {
  padding: 0.5rem 1rem;
  border-radius: 20px;
  font-size: 0.9rem;
  font-weight: 500;
}

.task-content {
  background: white;
  border-radius: 12px;
  padding: 2rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.section {
  margin-bottom: 2rem;
}

.section h3 {
  margin: 0 0 1rem 0;
  color: #666;
  font-size: 1rem;
  text-transform: uppercase;
}

.section p {
  margin: 0;
  line-height: 1.6;
  color: #333;
}

.details-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1.5rem;
}

.detail-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.detail-item label {
  font-size: 0.85rem;
  color: #999;
}

.detail-item value {
  font-weight: 500;
  color: #333;
}

.detail-item value.overdue {
  color: #f44336;
}

.task-actions {
  display: flex;
  gap: 1rem;
  margin-top: 2rem;
  padding-top: 2rem;
  border-top: 1px solid #e0e0e0;
}

.btn-complete, .btn-edit, .btn-delete {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-complete {
  background: #4caf50;
  color: white;
}

.btn-complete:hover {
  background: #388e3c;
}

.btn-edit {
  background: #2196f3;
  color: white;
}

.btn-edit:hover {
  background: #1976d2;
}

.btn-delete {
  background: #f44336;
  color: white;
  margin-left: auto;
}

.btn-delete:hover {
  background: #d32f2f;
}

.loading {
  text-align: center;
  padding: 3rem;
  color: #666;
}
</style>