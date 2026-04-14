# AGENTS

Este repositorio usa instrucciones por tarea para guiar agentes (Codex u otros) en cambios de software.

## Flujo recomendado
1. Crear un archivo de tarea en `tasks/` usando la plantilla `tasks/TASK_TEMPLATE.md`.
2. Completar requisitos, criterios de aceptación y comandos de validación.
3. Ejecutar el agente apuntando a ese archivo de tarea.
4. Verificar que el resultado incluya código, pruebas y documentación según lo solicitado.

## Convenciones
- Priorizar requisitos específicos y verificables.
- Incluir siempre alcance (`In/Out`) para evitar ambigüedad.
- Definir comandos de validación ejecutables en este repo.
- Pedir formato de salida final: resumen, archivos tocados, tests y riesgos.

## Ubicación de tareas
- Plantilla base: `tasks/TASK_TEMPLATE.md`
- Tareas concretas: `tasks/*.md`
