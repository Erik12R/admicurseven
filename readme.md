# Panel del Curso

Página web en línea para administrar un curso universitario:

- 📅 **Eventos** (con fecha de inicio y fin y estado automático: próximo / en curso / finalizado)
- 📝 **Deberes** (materia, fecha de entrega, pendiente / hecho)
- 🧪 **Pruebas / Exámenes** (fecha, peso, nota)
- 💵 **Finanzas del curso** (ingresos y gastos, con saldo)
- 🗓️ **Calendario** visual mensual
- 👥 **Equipo** (solo el admin reparte roles)

Roles:
- **admin** — todo, incluida la pestaña Equipo (reparte roles).
- **editor** — ver y **editar** el contenido del curso.
- **espectador** — **solo ver** (no puede crear, editar ni borrar).

Tú entras como **admin**; tú creas las cuentas y asignas el rol de cada persona.

La página es **responsiva** (se adapta a celular) y se **actualiza sola**
(lo que edita una persona lo ven las demás **sin recargar**, gracias a
Realtime de Supabase, que `schema.sql` ya activa).

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
2. Arrastra la **carpeta `admicurseven`** (con `index.html` dentro) a la zona
   *“Drag and drop your site output folder here”*.
3. Netlify te dará un **link** (puedes renombrarlo en *Site settings → Change site name*).

> Para actualizar: vuelve a arrastrar la carpeta, o conecta un repositorio de
> GitHub para que se publique solo con cada cambio.

### 7. Agregar a las otras personas
1. **Authentication → Users → Add user**: crea correo + contraseña de cada persona.
2. Entran al link con esos datos. Por defecto son **editor** (pueden editar).
3. En la pestaña **Equipo** (visible solo para ti) verás a todos y podrás
   cambiar el rol de cada uno en la lista:
   - **admin**, **editor** o **espectador** (solo lectura).

---

## Que los cambios se vean sin recargar

Ya viene **activado**: la sección 4 de `supabase/schema.sql` agrega las tablas a
Realtime. Verás un indicador **“En vivo”** (punto verde) en la barra superior;
si dice “Sin conexión”, revisa tu internet. Si además quieres comprobarlo a
mano: Supabase → **Database → Replication** y verifica que `eventos`,
`deberes`, `pruebas`, `finanzas` y `profiles` estén en la publicación
`supabase_realtime`.

---

## Notas de seguridad

- El `index.html` lleva la clave **anon**, que es **pública** por diseño: la
  protección real la dan las políticas **RLS** del `schema.sql`. No pongas la
  clave **service_role** en el archivo.
- Las cuentas solo las crea el admin (registro público desactivado).
- Guarda respaldos: en Supabase **Database → Backups**, o exporta cada tabla a CSV.

## Archivos

```
admicurseven/
├── index.html              # la página (pega aquí tus claves)
├── supabase/schema.sql     # tablas + roles + permisos (RLS) + realtime
└── readme.md               # este archivo
```
