package database

import "database/sql"

func SeedData(db *sql.DB) error {

	// Проверим есть ли уже статусы
	var count int
	err := db.QueryRow(`SELECT COUNT(*) FROM statuses`).Scan(&count)
	if err != nil {
		return err
	}

	if count == 0 {

		_, err := db.Exec(`
INSERT INTO statuses (name, color, order_index, is_default) VALUES
('Новая', '#3498db', 1, true),
('В процессе', '#f39c12', 2, false),
('Выполнена', '#27ae60', 3, false),
('На паузе', '#9b59b6', 4, false),
('Отменена', '#e74c3c', 5, false);
`)
		if err != nil {
			return err
		}
	}

	// Проверим приоритеты
	err = db.QueryRow(`SELECT COUNT(*) FROM priorities`).Scan(&count)
	if err != nil {
		return err
	}

	if count == 0 {

		_, err := db.Exec(`
INSERT INTO priorities (name, color, eisenhower_quad, order_index, is_default) VALUES
('P1 - Критический', '#e74c3c', 1, 1, true),
('P2 - Высокий', '#f39c12', 1, 2, false),
('P3 - Средний', '#f1c40f', 2, 3, false),
('P4 - Низкий', '#2ecc71', 3, 4, false),
('P5 - Опционально', '#95a5a6', 4, 5, false);
`)
		if err != nil {
			return err
		}
	}

	return nil
}
