<!-- src/components/TaskForm.vue -->
<template>
  <div class="modal-overlay" @click="$emit('close')">
    <div class="modal" @click.stop>
      <div class="modal-header">
        <h2>{{ isEdit ? 'Редактировать задачу' : 'Новая задача' }}</h2>
        <button class="close-btn" @click="$emit('close')">×</button>
      </div>

      <form @submit.prevent="handleSubmit" class="modal-body">
        <!-- Название -->
        <div class="form-group">
          <label>Название задачи *</label>
          <input 
            v-model="form.title"
            type="text"
            required
            placeholder="Введите название"
            class="form-input"
          />
        </div>

        <!-- Описание -->
        <div class="form-group">
          <label>Описание</label>
          <textarea 
            v-model="form.description"
            rows="4"
            placeholder="Введите описание"
            class="form-input"
          ></textarea>
        </div>

        <!-- Статус и Приоритет -->
        <div class="form-row">
          <div class="form-group">
            <label>Статус *</label>
            <select v-model="form.status_id" required class="form-select">
              <option value="" disabled>Выберите статус</option>
              <option 
                v-for="status in statuses" 
                :key="status.id"
                :value="status.id"
                :style="{ color: status.color }"
              >
                {{ status.name }}
              </option>
            </select>
          </div>

          <div class="form-group">
            <label>Приоритет *</label>
            <select v-model="form.priority_id" required class="form-select">
              <option value="" disabled>Выберите приоритет</option>
              <option 
                v-for="priority in priorities" 
                :key="priority.id"
                :value="priority.id"
                :style="{ color: priority.color }"
              >
                {{ priority.name }}
              </option>
            </select>
          </div>
        </div>

        <!-- Срок выполнения -->
        <div class="form-group">
          <label>Срок выполнения</label>
          <input 
            v-model="form.due_date"
            type="datetime-local"
            class="form-input"
          />
        </div>

        <div class="modal-footer">
          <button type="button" class="btn-cancel" @click="$emit('close')">
            Отмена
          </button>
          <button type="submit" class="btn-submit" :disabled="loading">
            {{ loading ? 'Сохранение...' : 'Сохранить' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useTaskStore } from '@/stores/taskStore'
import { referenceApi } from '@/api/referenceApi'

const props = defineProps({
  taskId: { type: String, default: null }
})
const emit = defineEmits(['close', 'saved'])

const store = useTaskStore()
const loading = ref(false)
const statuses = ref([])
const priorities = ref([])

const form = reactive({
  title: '',
  description: '',
  status_id: '',
  priority_id: '',
  due_date: ''
})

const isEdit = computed(() => !!props.taskId)

// 👇 Загрузка справочников при открытии формы
onMounted(async () => {
  try {
    const [statusesRes, prioritiesRes] = await Promise.all([
      referenceApi.getStatuses(),
      referenceApi.getPriorities()
    ])
    
    statuses.value = statusesRes.data || []
    priorities.value = prioritiesRes.data || []
    
    // Если редактируем - заполняем форму
    if (props.taskId) {
      await loadTaskData()
    } else {
      // Для новой задачи - устанавливаем значения по умолчанию
      if (statuses.value.length > 0) {
        form.status_id = statuses.value.find(s => s.is_default)?.id || statuses.value[0].id
      }
      if (priorities.value.length > 0) {
        form.priority_id = priorities.value.find(p => p.is_default)?.id || priorities.value[0].id
      }
    }
  } catch (error) {
    console.error('Failed to load references:', error)
    alert('Не удалось загрузить справочники')
  }
})

const loadTaskData = async () => {
  loading.value = true
  try {
    const task = await store.fetchTaskById(props.taskId)
    form.title = task.title
    form.description = task.description || ''
    form.status_id = task.status?.id || ''
    form.priority_id = task.priority?.id || ''
    form.due_date = task.due_date ? formatDateForInput(task.due_date) : ''
  } catch (error) {
    console.error('Failed to load task:', error)
  } finally {
    loading.value = false
  }
}

const formatDateForInput = (dateString) => {
  const date = new Date(dateString)
  return date.toISOString().slice(0, 16)
}

const formatDateForApi = (dateString) => {
  if (!dateString) return null
  const date = new Date(dateString)
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z')
}

const handleSubmit = async () => {
  // Валидация
  if (!form.title?.trim()) {
    alert('Введите название задачи')
    return
  }
  if (!form.status_id) {
    alert('Выберите статус')
    return
  }
  if (!form.priority_id) {
    alert('Выберите приоритет')
    return
  }

  loading.value = true
  try {
    const payload = {
      title: form.title.trim(),
      status_id: form.status_id,      // 👈 Теперь это реальный UUID
      priority_id: form.priority_id   // 👈 Теперь это реальный UUID
    }

    if (form.description?.trim()) {
      payload.description = form.description.trim()
    }
    if (form.due_date) {
      payload.due_date = formatDateForApi(form.due_date)
    }

    console.log('📤 Sending:', payload)

    if (isEdit.value) {
      await store.updateTask(props.taskId, payload)
    } else {
      await store.createTask(payload)
    }
    
    emit('saved')
    emit('close')
    
  } catch (error) {
    console.error('❌ Save error:', error)
    const msg = error.response?.data?.error || error.message || 'Ошибка сохранения'
    alert('Не удалось сохранить: ' + msg)
  } finally {
    loading.value = false
  }
}
</script>


<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.modal {
  background: white;
  border-radius: 16px;
  width: 100%;
  max-width: 600px;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #e0e0e0;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.5rem;
}

.close-btn {
  background: none;
  border: none;
  font-size: 2rem;
  cursor: pointer;
  color: #999;
  line-height: 1;
}

.close-btn:hover {
  color: #333;
}

.modal-body {
  padding: 1.5rem;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
  color: #333;
}

.form-input, .form-select {
  width: 100%;
  padding: 0.75rem;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 1rem;
  font-family: inherit;
  transition: border-color 0.2s;
}

.form-input:focus, .form-select:focus {
  outline: none;
  border-color: #2196f3;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.modal-footer {
  display: flex;
  gap: 1rem;
  justify-content: flex-end;
  padding-top: 1rem;
  border-top: 1px solid #e0e0e0;
}

.btn-cancel, .btn-submit {
  padding: 0.75rem 2rem;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-cancel {
  background: #f5f5f5;
  color: #333;
}

.btn-cancel:hover {
  background: #e0e0e0;
}

.btn-submit {
  background: #2196f3;
  color: white;
}

.btn-submit:hover:not(:disabled) {
  background: #1976d2;
}

.btn-submit:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>