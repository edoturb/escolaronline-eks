// EscolarOnline - Frontend CRUD - ACT2.3 EKS
const IS_LOCAL = window.location.hostname === 'localhost';
const API_BASE = IS_LOCAL ? 'http://localhost' : window.location.origin;

// En local (docker-compose): cada microservicio en su puerto directo.
// En EKS: todo pasa por el ALB Ingress -> Service frontend (puerto 80);
// el nginx.conf del frontend enruta internamente segun metodo HTTP.
const API_GET    = IS_LOCAL ? API_BASE + ':3001/api/products' : API_BASE + '/api/products';
const API_POST   = IS_LOCAL ? API_BASE + ':3002/api/products' : API_BASE + '/api/products';
const API_PUT    = IS_LOCAL ? API_BASE + ':3003/api/products' : API_BASE + '/api/products';
const API_DELETE = IS_LOCAL ? API_BASE + ':3004/api/products' : API_BASE + '/api/products';

document.addEventListener('DOMContentLoaded', cargarProductos);

async function cargarProductos() {
    try {
        const response = await fetch(API_GET);
        if (!response.ok) throw new Error('Error al cargar');
        const productos = await response.json();
        renderizarTabla(productos);
        mostrarMensaje('Productos cargados correctamente', 'exito');
    } catch (error) { mostrarMensaje('Error: ' + error.message, 'error'); }
}

function renderizarTabla(productos) {
    const tbody = document.getElementById('productos-body');
    tbody.innerHTML = '';
    if (productos.length === 0) { tbody.innerHTML = '<tr><td colspan="7">No hay productos</td></tr>'; return; }
    productos.forEach(p => {
        const tr = document.createElement('tr');
        tr.innerHTML = `<td>${p.id}</td><td>${p.nombre}</td><td>${p.descripcion || '-'}</td><td>$${Number(p.precio).toLocaleString('es-CL')}</td><td>${p.stock}</td><td>${p.categoria || '-'}</td><td><button class="btn-editar" onclick="editarProducto(${p.id},'${escapar(p.nombre)}','${escapar(p.descripcion||'')}',${p.precio},${p.stock},'${escapar(p.categoria||'')}')">Editar</button> <button class="btn-eliminar" onclick="eliminarProducto(${p.id})">Eliminar</button></td>`;
        tbody.appendChild(tr);
    });
}

async function guardarProducto(event) {
    event.preventDefault();
    const id = document.getElementById('producto-id').value;
    const datos = { nombre: document.getElementById('nombre').value, descripcion: document.getElementById('descripcion').value, precio: parseFloat(document.getElementById('precio').value), stock: parseInt(document.getElementById('stock').value), categoria: document.getElementById('categoria').value };
    try {
        let response;
        if (id) { response = await fetch(API_PUT + '/' + id, { method: 'PUT', headers: {'Content-Type':'application/json'}, body: JSON.stringify(datos) }); }
        else { response = await fetch(API_POST, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(datos) }); }
        if (!response.ok) { const err = await response.json(); throw new Error(err.error); }
        mostrarMensaje(id ? 'Producto modificado' : 'Producto creado', 'exito');
        limpiarFormulario(); cargarProductos();
    } catch (error) { mostrarMensaje('Error: ' + error.message, 'error'); }
}

async function eliminarProducto(id) {
    if (!confirm('Eliminar este producto?')) return;
    try {
        const response = await fetch(API_DELETE + '/' + id, { method: 'DELETE' });
        if (!response.ok) throw new Error('Error al eliminar');
        mostrarMensaje('Producto eliminado', 'exito'); cargarProductos();
    } catch (error) { mostrarMensaje('Error: ' + error.message, 'error'); }
}

function editarProducto(id, nombre, descripcion, precio, stock, categoria) {
    document.getElementById('producto-id').value = id;
    document.getElementById('nombre').value = nombre;
    document.getElementById('descripcion').value = descripcion;
    document.getElementById('precio').value = precio;
    document.getElementById('stock').value = stock;
    document.getElementById('categoria').value = categoria;
    document.getElementById('form-titulo').textContent = 'Editar Producto (ID: ' + id + ')';
    document.getElementById('btn-guardar').textContent = 'Actualizar';
}

function cancelarEdicion() { limpiarFormulario(); }
function limpiarFormulario() { document.getElementById('producto-form').reset(); document.getElementById('producto-id').value = ''; document.getElementById('form-titulo').textContent = 'Nuevo Producto'; document.getElementById('btn-guardar').textContent = 'Guardar'; }
function mostrarMensaje(texto, tipo) { const msg = document.getElementById('mensaje'); msg.textContent = texto; msg.className = tipo === 'exito' ? 'mensaje-exito' : 'mensaje-error'; setTimeout(() => { msg.textContent = ''; msg.className = ''; }, 4000); }
function escapar(str) { return str.replace(/'/g, "\\'").replace(/"/g, '\\"'); }

// 2026 - Disenador asignatura: Ignacio A. Pastenet M.
