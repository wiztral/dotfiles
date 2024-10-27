import { useEffect, useState } from "react";
import { createProviderGroup } from "zebar";
import { Button } from "./components/ui/button";
import { RiFlipHorizontal2Line, RiFlipVertical2Line } from "react-icons/ri";

const providers = createProviderGroup({
  network: { type: "network" },
  glazewm: { type: "glazewm" },
  cpu: { type: "cpu" },
  date: { type: "date", formatting: "EEE d MMM t" },
  battery: { type: "battery" },
  memory: { type: "memory" },
  weather: { type: "weather" },
});

function App() {
  const [output, setOutput] = useState(providers.outputMap);

  const { glazewm } = output;

  useEffect(() => {
    providers.onOutput((outputMap) => setOutput(outputMap));
  }, []);

  return (
    <div className="grid grid-cols-2">
      <div className="flex items-center gap-1 px-0.5 py-0.5">
        {glazewm &&
          glazewm.currentWorkspaces.map((workspace) => (
            <Button
              key={workspace.name}
              size={"icon"}
              variant={
                workspace.hasFocus
                  ? "default"
                  : workspace.isDisplayed
                    ? "secondary"
                    : "ghost"
              }
              onClick={() =>
                glazewm.runCommand(`focus --workspace ${workspace.name}`)
              }
            >
              {workspace.displayName ?? workspace.name}
            </Button>
          ))}
      </div>

      <div className="flex items-center gap-1 justify-self-end px-0.5 py-0.5">
        {glazewm && (
          <>
            {glazewm.bindingModes.map((bindingMode) => (
              <Button key={bindingMode.name} variant={"ghost"}>
                {bindingMode.displayName ?? bindingMode.name}
              </Button>
            ))}
            <Button
              variant={"ghost"}
              onClick={() => glazewm.runCommand("toggle-tiling-direction")}
            >
              {glazewm.tilingDirection === "horizontal" ? (
                <RiFlipHorizontal2Line className="h-5 w-5" />
              ) : (
                <RiFlipVertical2Line className="h-5 w-5" />
              )}
            </Button>
          </>
        )}
      </div>
    </div>
  );
}

export default App;
