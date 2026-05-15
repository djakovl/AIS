<template>
  <div class="task-list">
    <div v-if="loading" class="loading">Загрузка...</div>
    
    <div v-else-if="tasks.length === 0" class="empty-state">
      <p>Нет задач</p>
    </div>

    <div v-else class="tasks-container">
      <TaskCard 
        v-for="task in tasks" 
        :key="task.id" 
        :task="task"
        @click="viewTask(task.id)"
        @complete="toggleComplete(task)"
      />
    </div>
  </div>
</template>

<script setup>
import { defineProps } from 'vue'
import { useRouter } from 'vue-router'
import TaskCard from './TaskCard.vue'

const props = defineProps({
  tasks: {
    type: Array,
    required: true
  },
  loading: {
    type: Boolean,
    default: false
  }
})

const router = useRouter()

const viewTask = (id) => {
  router.push(`/tasks/${id}`)
}

const toggleComplete = async (task) => {
  // Emit event to parent component
  emit('complete', task)
}

const emit = defineEmits(['complete'])
</script>

<style scoped>
.task-list {
  padding: 1rem;
}

.loading {
  text-align: center;
  padding: 2rem;
  color: #666;
}

.empty-state {
  text-align: center;
  padding: 3rem;
  color: #999;
}

.tasks-container {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
</style>