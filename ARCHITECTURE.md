# 🏗️ Arquitectura del Proyecto

## 📁 Estructura de Carpetas

Este proyecto sigue una **arquitectura por features** (característica modular), que facilita:

- ✅ Escalabilidad
- ✅ Mantenimiento
- ✅ Trabajo en equipo
- ✅ Testing independiente

```
lib/
├── core/                           # Configuración global
│   ├── theme/                      # Temas y estilos
│   │   ├── app_theme.dart
│   │   └── app_exceptions.dart
│   ├── constants/                  # Constantes de la app
│   │   └── app_constants.dart
│   ├── services/                   # Servicios globales
│   │   └── firebase_service.dart
│   └── utils/                      # Utilidades globales
│
├── features/                       # Módulos por funcionalidad
│   ├── auth/                       # 🔐 Autenticación
│   │   ├── data/                   # Servicios y repositorios
│   │   │   └── user_service.dart
│   │   └── presentation/           # UI y lógica de presentación
│   │       ├── pages/
│   │       │   ├── login_page.dart
│   │       │   └── register_page.dart
│   │       └── widgets/            # Widgets específicos de auth
│   │
│   ├── home/                       # 🏠 Dashboard principal
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── home_page.dart
│   │       └── widgets/
│   │
│   ├── transactions/               # 💰 Gestión de ingresos y gastos
│   │   ├── data/
│   │   │   ├── expense_service.dart
│   │   │   └── income_service.dart
│   │   └── presentation/
│   │       └── pages/
│   │           ├── add_expense_page.dart
│   │           ├── add_income_page.dart
│   │           └── transactions_list_page.dart
│   │
│   ├── budget/                     # 📊 Presupuestos
│   │   ├── data/
│   │   │   └── budget_service.dart
│   │   └── presentation/
│   │       └── pages/
│   │           └── budget_page.dart
│   │
│   ├── analytics/                  # 📈 Métricas y gráficas
│   │   ├── data/
│   │   │   └── metrics_service.dart
│   │   └── presentation/
│   │       └── pages/
│   │           └── analytics_page.dart
│   │
│   ├── achievements/               # 🏆 Gamificación y logros
│   │   ├── data/
│   │   │   └── achievement_service.dart
│   │   └── presentation/
│   │       └── pages/
│   │           └── achievements_page.dart
│   │
│   ├── profile/                    # 👤 Perfil de usuario
│   │   └── presentation/
│   │       └── pages/
│   │           └── profile_page.dart
│   │
│   └── ai_assistant/               # 🤖 Asistente IA
│       ├── data/
│       │   └── ai_service.dart
│       └── presentation/
│           └── pages/
│               └── ai_chat_page.dart
│
├── shared/                         # Compartido entre features
│   ├── models/                     # Modelos de datos
│   │   ├── user_model.dart
│   │   ├── expense_model.dart
│   │   ├── income_model.dart
│   │   ├── budget_model.dart
│   │   ├── achievement_model.dart
│   │   └── metrics_model.dart
│   ├── widgets/                    # Widgets reutilizables
│   │   ├── custom_button.dart
│   │   └── custom_text_field.dart
│   └── utils/                      # Utilidades compartidas
│
└── main.dart                       # Punto de entrada
```

## 🎯 Principios de Arquitectura

### 1. Separación por Capas

Cada feature tiene:

- **Data**: Lógica de datos (servicios, repositorios)
- **Presentation**: UI (páginas, widgets)
- **Domain** (opcional): Lógica de negocio compleja

### 2. Modelos Compartidos

Los modelos en `shared/models/` son usados por múltiples features:

- ✅ `user_model.dart` - Usuario
- ✅ `expense_model.dart` - Gastos
- ✅ `income_model.dart` - Ingresos
- ✅ `budget_model.dart` - Presupuestos
- ✅ `achievement_model.dart` - Logros
- ✅ `metrics_model.dart` - Métricas financieras

### 3. Widgets Compartidos

Componentes reutilizables en `shared/widgets/`:

- `custom_button.dart`
- `custom_text_field.dart`
- etc.

### 4. Core Global

Configuraciones y servicios globales:

- **Theme**: Diseño UI global
- **Constants**: Categorías, niveles, etc.
- **Services**: Firebase, Auth

## 🚀 Arranque y UX

- `main.dart` espera `EnvConfig.load()`, `Firebase.initializeApp()` y la activación de App Check antes de `runApp`.
- Las notificaciones se inicializan en background con `_initNotifications()`, para no bloquear el primer frame.
- Los accesos directos se inicializan en background con `_initShortcuts()`.
- `SplashScreen` anima el logo por `700 ms` y navega al terminar la animación, sin delay fijo.
- El botón central `+` del home abre `QuickAddSheet`, que espera el resultado de Firestore antes de confirmar el guardado y actualizar las estadísticas.

## ✍️ Registro inteligente

- Texto libre: `QuickAddSheet` usa `LocalTransactionParser` sin red; si faltan datos, consulta `TransactionExtractionService`. El usuario revisa y confirma el borrador antes de guardarlo.
- Voz: `speech_to_text` convierte el dictado en texto y lo envía al mismo flujo de interpretación.
- La entrada de foto y cámara está temporalmente retirada del registro rápido. `TransactionExtractionService` conserva la extracción de imágenes para una futura interfaz.
- Accesos directos: `quick_actions` ofrece «Nuevo gasto» y «Nuevo ingreso» y conserva la acción hasta que `HomePage` pueda abrir el sheet.
- IA: Firebase AI Logic usa App Check; la app no incluye una API key de Gemini. La configuración de AI Logic y App Check se completa en Firebase Console.
- Categorías: `TransactionCategories` define nombres, íconos y colores para gastos e ingresos en un solo lugar.
- Estadísticas: el home notifica los guardados y la página recarga la dona por categoría, la tendencia de seis meses y el ritmo frente al presupuesto.

## 🏆 Gamificación

- El punto de entrada único post-transacción es `GamificationService.onTransactionRegistered(...)`.
- El flujo de recompensas corre en este orden: sumar puntos por acción, actualizar racha persistente en `users/{uid}`, evaluar logros.
- Los puntos del usuario se actualizan con transacciones de Firestore para evitar carreras.
- Los logros usan IDs determinísticos (`{uid}_{key}`) y se crean con `unlockedAt` desde el inicio para que el desbloqueo sea idempotente.
- La pantalla de logros mezcla documentos desbloqueados de Firestore con templates locales para mostrar también los pendientes.

## 🔄 Flujo de Datos

```
UI (Page) → Service → Firebase → Model → UI
```

Ejemplo:

```dart
// Registro rápido desde el home
QuickAddSheet() → transactionService.createExpense()/createIncome()
                → Firestore
                → Navigator.pop() tras confirmar el guardado
                → HomePage aplica balance optimista
                → GamificationService.onTransactionRegistered() en background
```

## 📦 Dependencias entre Features

```
auth ← home
     ← transactions
     ← budget
     ← analytics
     ← achievements
     ← profile
     ← ai_assistant
```

Todos los features dependen de:

- `core/` (tema, servicios)
- `shared/` (modelos, widgets)

## 📝 Convenciones de Código

- **Nombres de archivos**: `snake_case.dart`
- **Nombres de clases**: `PascalCase`
- **Nombres de variables**: `camelCase`
- **Constantes**: `UPPER_CASE`
- **Imports**: Ordenados (dart → flutter → packages → local)

## 🧪 Testing

Estructura de tests (a implementar):

```
test/
├── features/
│   ├── auth/
│   ├── transactions/
│   └── ...
└── shared/
```
