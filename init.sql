-- ============================================
-- EscolarOnline - Base de Datos (RDS MySQL)
-- Actividad 2.3 - Arquitectura Cloud ARY1102
-- ============================================
-- Ejecutar en RDS MySQL Multi-AZ via mysql client
-- Conexion: mysql -h <RDS_ENDPOINT> -u alumno -palumno123

CREATE DATABASE IF NOT EXISTS escolar_online;
USE escolar_online;

-- Tabla de productos escolares
CREATE TABLE IF NOT EXISTS productos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    categoria VARCHAR(100),
    imagen_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Datos de prueba: 5 productos escolares
INSERT INTO productos (nombre, descripcion, precio, stock, categoria) VALUES
('Cuaderno universitario 100 hojas', 'Cuaderno matematicas cuadro grande, tapa dura, 100 hojas', 2990.00, 150, 'Cuadernos'),
('Mochila escolar reforzada', 'Mochila con compartimentos, material resistente al agua, correas acolchadas', 24990.00, 45, 'Mochilas'),
('Set 12 lapices de colores', 'Lapices de colores profesionales, mina suave, 12 unidades', 4990.00, 200, 'Lapices'),
('Calculadora cientifica', 'Calculadora cientifica 240 funciones, pantalla LCD, incluye tapa protectora', 12990.00, 60, 'Tecnologia'),
('Estuche escolar doble cierre', 'Estuche amplio con doble compartimento y cierre metalico', 6990.00, 80, 'Estuches');

-- 2026 - Disenador asignatura: Ignacio A. Pastenet M.
