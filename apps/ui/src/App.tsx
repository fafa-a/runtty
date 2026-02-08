import { createSignal } from "solid-js"
import { Sidebar } from "~/components/ui/sidebar"
import "./App.css"

interface Project {
  name: string
  path: string
}

// WebUI is loaded via script tag in index.html
declare const webui: {
  call: (eventId: string, data?: string) => Promise<string>
  bind: (eventId: string, callback: (data: string) => void) => void
}

function App() {
  const [projects, setProjects] = createSignal<Project[]>([])
  const [error, setError] = createSignal<string | null>(null)
  const [runningProjects, setRunningProjects] = createSignal<Set<string>>(new Set())

  // Listen for project status updates from backend
  if (typeof webui !== 'undefined' && webui.bind) {
    webui.bind("project.status", (data: string) => {
      const status = JSON.parse(data)
      if (status.status === "running" && status.path) {
        setRunningProjects(prev => {
          const next = new Set(prev)
          next.add(status.path)
          return next
        })
      } else if (status.status === "stopped" && status.path) {
        setRunningProjects(prev => {
          const next = new Set(prev)
          next.delete(status.path)
          return next
        })
      }
    })
  }

  const handleOpenFile = async () => {
    setError(null)

    try {
      // Call backend via WebUI
      const response = await webui.call("folder.pick")
      const data = JSON.parse(response)

      if (data.error) {
        if (data.error === "user_cancelled") {
          return
        }
        setError(`Error: ${data.error}`)
        setProjects([])
        return
      }

      if (!data.folders || data.folders.length === 0) {
        setError("No subdirectories found")
        setProjects([])
      } else {
        const newProjects = data.folders.map((name: string) => ({
          name,
          path: `${data.path}/${name}`,
        }))
        setProjects(newProjects)
        setError(null)
      }
    } catch (err) {
      console.error("Failed to pick folder:", err)
      setError(`Failed: ${err instanceof Error ? err.message : String(err)}`)
    }
  }

  const handlePlay = async (project: Project) => {
    try {
      const response = await webui.call("project.start", JSON.stringify({
        path: project.path,
        command: 0 // Use first command (dev/run)
      }))
      const data = JSON.parse(response)
      
      // Update running state immediately
      if (data.status === "running") {
        setRunningProjects(prev => {
          const next = new Set(prev)
          next.add(project.path)  // Use path as key
          return next
        })
      }
    } catch (err) {
      console.error("Failed to start project:", err)
      setError(`Failed to start: ${err instanceof Error ? err.message : String(err)}`)
    }
  }

  const handleStop = async (project: Project) => {
    try {
      const response = await webui.call("project.stop", JSON.stringify({
        path: project.path
      }))
      const data = JSON.parse(response)
      
      // Update running state immediately
      if (data.status === "stopped") {
        setRunningProjects(prev => {
          const next = new Set(prev)
          next.delete(project.path)  // Use path as key
          return next
        })
      }
    } catch (err) {
      console.error("Failed to stop project:", err)
      setError(`Failed to stop: ${err instanceof Error ? err.message : String(err)}`)
    }
  }

  return (
    <div class="h-screen flex bg-background text-foreground">
      <Sidebar
        projects={projects()}
        onOpenFile={handleOpenFile}
        onPlay={handlePlay}
        onStop={handleStop}
        runningProjects={runningProjects}
      />

      <div class="flex-1 flex items-center justify-center p-8">
        <div class="text-center">
          <h1 class="text-3xl font-bold mb-4">RunTTY</h1>
          <p class="text-muted-foreground mb-4">
            Terminal Emulator avec WebView
          </p>
          <p class="text-sm text-muted-foreground">
            Utilisez la sidebar pour sélectionner un projet
          </p>
          {error() && (
            <p class="text-sm text-destructive mt-4">{error()}</p>
          )}
        </div>
      </div>
    </div>
  )
}

export default App
