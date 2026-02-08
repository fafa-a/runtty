import { For, createSignal } from "solid-js"
import { Button } from "~/components/ui/button"
import { Separator } from "~/components/ui/separator"
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "~/components/ui/collapsible"

interface Project {
  name: string
  path: string
}

interface SidebarProps {
  projects: Project[]
  onOpenFile: () => void
  onPlay: (project: Project) => void
  onStop: (project: Project) => void
  runningProjects?: () => Set<string>
}

export function Sidebar(props: SidebarProps) {
  const [openProjects, setOpenProjects] = createSignal<Set<string>>(new Set())

  const toggleProject = (name: string) => {
    setOpenProjects((prev) => {
      const next = new Set(prev)
      if (next.has(name)) {
        next.delete(name)
      } else {
        next.add(name)
      }
      return next
    })
  }

  return (
    <div class="w-64 h-full bg-background border-r border-border flex flex-col">
      {/* Header */}
      <div class="p-4 border-b border-border">
        <h2 class="text-lg font-semibold mb-2">Workspace</h2>
        <Button onClick={props.onOpenFile} class="w-full">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="mr-2"
          >
            <path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 2H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2z" />
          </svg>
          Open Workspace
        </Button>
      </div>

      <Separator />

      {/* Projects List */}
      <div class="flex-1 overflow-y-auto p-2">
        <For each={props.projects}>
          {(project) => (
            <Collapsible
              open={openProjects().has(project.name)}
              onOpenChange={() => toggleProject(project.name)}
              class="mb-2"
            >
              <CollapsibleTrigger>
                <div class="flex items-center justify-between w-full py-2 px-3 rounded-md hover:bg-accent hover:text-accent-foreground cursor-pointer select-none">
                  <div class="flex items-center">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      class="mr-2"
                    >
                      <path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" />
                    </svg>
                    <span class="font-medium truncate">{project.name}</span>
                  </div>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class={`transition-transform ${openProjects().has(project.name) ? "rotate-180" : ""}`}
                  >
                    <path d="m6 9 6 6 6-6" />
                  </svg>
                </div>
              </CollapsibleTrigger>
              <CollapsibleContent>
                <div class="pl-4 pr-2 py-2 bg-muted/50 rounded-md mt-1">
                  <div class="flex gap-2">
                    <Button
                      variant={props.runningProjects?.().has(project.path) ? "default" : "outline"}
                      size="sm"
                      onClick={() => props.onPlay(project)}
                      class={`flex-1 ${props.runningProjects?.().has(project.path) ? "bg-green-600 hover:bg-green-700" : ""}`}
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        width="14"
                        height="14"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        class="mr-1"
                      >
                        <polygon points="5 3 19 12 5 21 5 3" />
                      </svg>
                      {props.runningProjects?.().has(project.path) ? "Running" : "Play"}
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => props.onStop(project)}
                      class="flex-1"
                      disabled={!props.runningProjects?.().has(project.path)}
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        width="14"
                        height="14"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        class="mr-1"
                      >
                        <rect x="4" y="4" width="16" height="16" rx="2" />
                      </svg>
                      Stop
                    </Button>
                  </div>
                </div>
              </CollapsibleContent>
            </Collapsible>
          )}
        </For>

        {props.projects.length === 0 && (
          <div class="text-center text-muted-foreground py-8">
            <p>No projects found</p>
            <p class="text-sm mt-1">Click "Open File" to select a workspace</p>
          </div>
        )}
      </div>
    </div>
  )
}
