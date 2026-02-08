import { createSignal } from "solid-js"
import { Sidebar } from "~/components/ui/sidebar"
import "./App.css"

interface Project {
  name: string
  path: string
}

// WebUI global type
declare global {
  interface Window {
    webui?: {
      call: (eventId: string, data?: string) => Promise<string>
    }
  }
}

function App() {
  const [projects, setProjects] = createSignal<Project[]>([])
  const [error, setError] = createSignal<string | null>(null)

  const handleOpenFile = async () => {
    setError(null)

    // Check if running in WebUI context
    if (!window.webui) {
      setError("Not running in WebUI context - folder picker unavailable")
      return
    }

    try {
      // Call Zig backend API
      const response = await window.webui.call("/api/folder/pick")
      const data = JSON.parse(response)

      if (data.error) {
        if (data.error === "user_cancelled") {
          // User cancelled - no error to show
          return
        }
        setError(`Error: ${data.error}`)
        setProjects([])
        return
      }

      if (!data.folders || data.folders.length === 0) {
        setError("No subdirectories found in selected folder")
        setProjects([])
      } else {
        // Convert folder names to Project objects
        const newProjects = data.folders.map((name: string) => ({
          name,
          path: `${data.path}/${name}`,
        }))
        setProjects(newProjects)
        setError(null)
      }
    } catch (err) {
      console.error("Failed to pick folder:", err)
      setError("Failed to open folder picker")
    }
  }

  const handlePlay = (project: Project) => {
    console.log(`Play project: ${project.name} at ${project.path}`)
    // TODO: Call Zig API to run project
  }

  const handleStop = (project: Project) => {
    console.log(`Stop project: ${project.name}`)
    // TODO: Call Zig API to stop project
  }

  return (
    <div class="h-screen flex bg-background text-foreground">
      <Sidebar
        projects={projects()}
        onOpenFile={handleOpenFile}
        onPlay={handlePlay}
        onStop={handleStop}
      />

      {/* Main Content */}
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
