# Panel del Curso

Página web en línea para administrar un curso universitario:

- 📅 **Eventos** (con fecha de inicio y fin y estado automático: próximo / en curso / finalizado)
- 📝 **Deberes** (materia, fecha de entrega, pendiente / hecho)
- 🧪 **Pruebas / Exámenes** (fecha, peso, nota)
- 💵 **Finanzas del curso** (ingresos y gastos, con saldo)
- 🗓️ **Calendario** visual mensual
- 👥 **Equipo** (solo el admin reparte roles)

Tú eres **admin**; los demás entran como **editor**. Para sumar personas,
tú (admin) creas sus cuentas y ellos editan todo lo del curso.

## Tecnología

- **Frontend:** un solo `index.html` (sin frameworks, usa el cliente JS de Supabase por CDN).
- **Backend / datos / login:** [Supabase](https://supabase.com) (plan gratuito).
- **Hosting del link:** [Netlify](https://netlify.com) (gratis), o GitHub Pages / Vercel.

---

## Montaje paso a paso (una vez)

### 1. Crear el proyecto en Supabase
1. Entra a <https://supabase.com> → **Start your project** (gratis).
2. Crea un proyecto nuevo (elige una contraseña de base de datos y guarda la región US East o la más cercana).

### 2. Crear las tablas
1. En el proyecto: **SQL Editor → New query**.
2. Pega **todo** el contenido de `supabase/schema.sql` y pulsa **Run**.

### 3. Configurar el login
1. **Authentication → Providers → Email**: deja habilitado Email.
2. En **Authentication → Sign In / Providers** (o *Email*), **desactiva
   “Allow new users to sign up”**. Así **nadie** se registra solo: solo tú creas cuentas.
3. Opcional (recomendado para pruebas): desactiva **“Confirm email”** para que
   las cuentas entren sin confirmar el correo.

### 4. Crear TU cuenta y volverte admin
1. **Authentication → Users → Add user → Create new user**: escribe tu correo y contraseña.
2. Vuelve a **SQL Editor** y ejecuta (cambiando tu correo):

   ```sql
   update public.profiles set role = 'admin'
   where email = 'TU_CORREO@ejemplo.com';
   ```

### 5. Conectar la página con tu proyecto
1. **Project Settings → API**: copia **Project URL** y la clave **anon public**.
2. Abre `index.html` y pega esos dos valores arriba del todo:

   ```js
   const SUPABASE_URL = "https://TU-PROYECTO.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOi...";   // anon public
   ```

### 6. Publicar para tener el link
1. Entra a <https://netlify.com> → inicia sesión.
2. Arrastra la **carpeta `curso-admin`** (con `index.html` dentro) a la zona
   *“Drag and drop your site output folder here”*.
3. Netlify te dará un **link** (puedes renombrarlo en *Site settings → Change site name*).

> Para actualizar: vuelve a arrastrar la carpeta, o conecta un repositorio de
> GitHub para que se publique solo con cada cambio.

### 7. Agregar a las otras personas (editores)
1. **Authentication → Users → Add user**: crea correo + contraseña de cada persona.
2. Entran al link con esos datos y ya pueden editar eventos, deberes, pruebas y finanzas.
3. En la pestaña **Equipo** (visible solo para ti) verás a todos y podrás
   **hacer admin** a quien quieras.

---

## Que los cambios se vean sin recargar (opcional)

Para que si uno edita, los demás lo vean al instante:

1. Supabase → **Database → Replication**.
2. Activa **Realtime** para las tablas `eventos`, `deberes`, `pruebas`,
   `finanzas` y `profiles` (botón *Source* / añadir a la publicación).

Si no lo activas, todo funciona igual; solo hay que recargar la página.

---

## Notas de seguridad

- El `index.html` lleva la clave **anon**, que es **pública** por diseño: la
  protección real la dan las políticas **RLS** del `schema.sql`. No pongas la
  clave **service_role** en el archivo.
- Las cuentas solo las crea el admin (registro público desactivado).
- Guarda respaldos: en Supabase **Database → Backups**, o exporta cada tabla a CSV.

## Archivos

```
curso-admin/
├── index.html              # la página (pega aquí tus claves)
├── supabase/schema.sql     # tablas + roles + permisos (RLS)
└── README.md               # este archivo
```
