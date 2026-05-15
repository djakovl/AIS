<template>
  <div class="task-card" :class="{ completed: task.is_completed }" @click="$emit('click', task)">
    <!-- Цветная полоска приоритета -->
    <div 
      class="task-priority-indicator" 
      :style="{ backgroundColor: task.priority?.color || '#ccc' }"
    ></div>
    
    <div class="task-content">
      <h3 class="task-title">{{ task.title }}</h3>
      
      <div class="task-meta">
        <!-- Приоритет -->
        <span 
          class="task-priority" 
          :style="{ 
            backgroundColor: task.priority?.color + '20',
            color: task.priority?.color 
          }"
        >
          {{ task.priority?.name || 'Приоритет' }}
        </span>
        
        <!-- Срок выполнения -->
        <span v-if="task.due_date" class="task-due-date" :class="{ overdue: isOverdue(task.due_date) }">
          📅 {{ formatDate(task.due_date) }}
        </span>
      </div>

      <!-- Статус -->
      <div class="task-status">
        <span 
          class="status-badge" 
          :style="{ 
            backgroundColor: task.status?.color + '20',
            color: task.status?.color 
          }"
        >
          {{ task.status?.name || 'Статус' }}
        </span>
      </div>
    </div>

    <div class="task-actions">
      <button 
        v-if="!task.is_completed" 
        class="complete-btn"
        @click.stop="$emit('complete', task)"
        title="Завершить"
      >
        ✓
      </button>
      <button class="more-btn" @click.stop="$emit('more', task)">
        ⋮
      </button>
    </div>
  </div>
</template>

<script setup>
import { defineProps, defineEmits } from 'vue'

const props = defineProps({
  task: {
    type: Object,
    required: true,
    // Ожидаемая структура:
    // {
    //   id, title, is_completed, due_date,
    //   status: { id, name, color },
    //   priority: { id, name, color }
    // }
  }
})

defineEmits(['click', 'complete', 'more'])

const formatDate = (dateString) => {
  const date = new Date(dateString)
  return date.toLocaleDateString('ru-RU', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  })
}

const isOverdue = (dateString) => {
  return new Date(dateString) < new Date()
}
</script>

<style scoped>
.task-card {
  background: white;
  border-radius: 12px;
  padding: 1rem;
  display: flex;
  gap: 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
  position: relative;
  overflow: hidden;
}

.task-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}

.task-card.completed {
  opacity: 0.7;
}

.task-card.completed .task-title {
  text-decoration: line-through;
  color: #999;
}

.task-priority-indicator {
  width: 4px;
  border-radius: 2px;
  min-height: 100px;
}

.task-content {
  flex: 1;
}

.task-title {
  margin: 0 0 0.5rem 0;
  font-size: 1.1rem;
  color: #333;
}

.task-meta {
  display: flex;
  gap: 1rem;
  margin-bottom: 0.5rem;
  flex-wrap: wrap;
}

.task-priority {
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.85rem;
  font-weight: 500;
}

.task-due-date {
  font-size: 0.85rem;
  color: #666;
}

.task-due-date.overdue {
  color: #f44336;
  font-weight: 600;
}

.status-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.85rem;
  font-weight: 500;
}

.task-actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.complete-btn, .more-btn {
  border: none;
  background: #f5f5f5;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  cursor: pointer;
  font-size: 1.2rem;
  transition: background 0.2s;
}

.complete-btn:hover {
  background: #4caf50;
  color: white;
}

.more-btn:hover {
  background: #e0e0e0;
}
</style>