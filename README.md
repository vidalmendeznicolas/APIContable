
#  API REST Contable

Este proyecto es una API REST desarrollada en **Delphi** usando el framework **Horse**, que permite registrar operaciones contables bajo el principio de partida doble.  
Admite entrada de datos en formato **JSON** y **XML**, y utiliza **SQLite** como base de datos.

---

##  Características

- Registro de operaciones contables.
- Comprobación de que el **DEBE** y el **HABER** están equilibrados.
- Soporte para entrada de datos en **JSON** y **XML**.
- Almacenamiento en base de datos SQLite.
- API sencilla y extensible.

---

##  Requisitos

- Delphi IDE (Recomendado: **Delphi Community Edition 11 o superior**).
- Git
- Postman o cualquier cliente REST (para pruebas).
- DB Browser for SQLite: Para generar la base de datos y las tablas necesarias.

---

## Base de datos
- Por defecto, la API utiliza un fichero `delphi.db` en SQLite

##  Tablas de la base de datos

	CREATE TABLE operaciones (
		id SERIAL PRIMARY KEY,
		fecha_operacion DATE NOT NULL,
		descripcion TEXT,
		fecha_insercion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE apuntes (
		id SERIAL PRIMARY KEY,
		operacion_id INTEGER REFERENCES operaciones(id) ON DELETE CASCADE,
		codigo_cuenta VARCHAR(20) NOT NULL,
		importe NUMERIC(12,2) NOT NULL CHECK (importe > 0),
		tipo VARCHAR(5) CHECK (tipo IN ('DEBE', 'HABER')) NOT NULL
	);


##  Librerías necesarias

1. **Horse**
   - [https://github.com/HashLoad/horse](https://github.com/HashLoad/horse)

   Instalar:
   ```bash
   git clone https://github.com/HashLoad/horse.git
   ```

   Luego añadir la ruta del directorio `src` al proyecto en:
   ```
   Project > Options > Delphi Compiler > Search Path
   ```
    Ej: C:\Users\Administrador\Desktop\Project Delphi\horse\src
2. **Jhonson** (para entrada en JSON)
   - [https://github.com/HashLoad/jhonson.git](https://github.com/HashLoad/jhonson.git)

   Instalar:
   ```bash
   git clone https://github.com/HashLoad/jhonson.git
   ```

   Luego añadir la ruta del directorio `src` al proyecto en:
   ```
   Project > Options > Delphi Compiler > Search Path
   ```
   Ej: C:\Users\Administrador\Desktop\Project Delphi\jhonson\src

3. **OmniXML** (para entrada en XML si no tienes MSXML)
   - [https://github.com/mremec/omnixml](https://github.com/mremec/omnixml)

   Instalar:
   ```bash
   git clone https://github.com/mremec/omnixml.git
   ```
	
	Luego añadir la ruta del directorio `omnixml` al proyecto en:
   ```
   Project > Options > Delphi Compiler > Search Path
   ```
   Ej: C:\Users\Administrador\Desktop\Project Delphi\omnixml

---

##  Configuración del proyecto

1. **Abrir el proyecto** (`.dpr`) con Delphi.
2. Verificar que el **framework Horse** está referenciado en las rutas del proyecto.
3. Si usas SQLite tienes que colocar la base de datos junto al .exe del programa 
	(C:\Users\Administrador\Documents\Embarcadero\Studio\Projects\Win32\Debug)

- NOTA:
	Si hay problemas al abrir, se puede crear un nuevo proyecto tal que así:
	File -> New -> Console Application - Delphi
	Copiamos el código fuente y añadimos las librerías descargadas en:
	Project -> Options -> Building -> Delphi Compiler -> Search path 
	y añadimos las tres rutas donde hubiéramos descargado las librerias necesarias.
---

##  Endpoints disponibles

##  POST `/api/operaciones`

**Contenido JSON**
```json
{
  "fecha_operacion": "2025-07-07",
  "descripcion": "Pago de factura",
  "apuntes": [
    { "codigo_cuenta": "430000", "importe": 1000.00, "tipo": "DEBE" },
    { "codigo_cuenta": "700000", "importe": 1000.00, "tipo": "HABER" }
  ]
}
```

**Contenido XML**
```xml
<operacion>
  <fecha_operacion>07-07-2025</fecha_operacion>
  <descripcion>Desde XML</descripcion>
  <apuntes>
    <apunte>
      <codigo_cuenta>430000</codigo_cuenta>
      <importe>1000.00</importe>
      <tipo>DEBE</tipo>
    </apunte>
    <apunte>
      <codigo_cuenta>700000</codigo_cuenta>
      <importe>1000.00</importe>
      <tipo>HABER</tipo>
    </apunte>
  </apuntes>
</operacion>
```

 *Content-Type requerido:*
- `application/json` o `application/xml`

 *Respuesta exito:*
```json
{
  "mensaje": "Operación registrada correctamente",
  "id_operacion": 1
}
```
 *Respuesta error:*
```json
{
    "error": "La suma del debe (400,00) no coincide con la suma del haber (4060,00)"
}
```
###  GET `/api/operaciones/:id`

Devuelve los datos de una operación contable por su ID.

---

## Pruebas

Se recomienda usar [Postman](https://www.postman.com/) o [curl](https://curl.se/) para enviar peticiones de prueba.
En caso de POST: http://localhost:9000/api/operaciones
En caso de GET: http://localhost:9000/api/operaciones/1

---

##  Notas

- El formato de fecha en XML debe ser `dd-mm-yyyy`.

---

##  Licencia

MIT Nicolás Vidal Méndez
