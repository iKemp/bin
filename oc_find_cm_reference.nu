#!/usr/bin/env nu

def main [
    search_term?: string,      # Optional term to filter ConfigMaps
    --namespace (-n): string   # Optional: "dev" or "dev,staging,prod"
] {
    # 1. Prepare the list of namespaces to iterate over
    let ns_list = if ($namespace != null) { 
        $namespace | split row "," | str trim 
    } else { 
        [null] # 'null' tells 'oc' to use the current context
    }

    # 2. Iterate through namespaces and collect data
    let data = $ns_list | each {|ns|
        let oc_args = if ($ns != null) {
            ["get" "deployments,dc" "-n" $ns "-o" "json"]
        } else {
            ["get" "deployments,dc" "-o" "json"]
        }
        
        # Run oc and get items safely
        run-external "oc" ...$oc_args e> /dev/null 
        | from json 
        | get items 
        | default []
    } | flatten

    if ($data | is-empty) { 
        print "No deployments or DCs found in the specified namespace(s)."
        return 
    }

    # 3. Process the results
    let results = ($data | insert config_maps {|it| 
        let spec = $it.spec.template.spec
        
        let bulk = ($spec.containers | each {|c| 
            $c.envFrom? | default [] | each {|ef| $ef.configMapRef?.name? } 
        } | flatten)

        let single = ($spec.containers | each {|c| 
            $c.env? | default [] | each {|e| $e.valueFrom?.configMapKeyRef?.name? } 
        } | flatten)

        let vols = ($spec.volumes? | default [] | each {|v| $v.configMap?.name? } | flatten)

        ([$bulk $single $vols] | flatten | compact | uniq | str join ", ")
    })

    # 4. Final View
    let view = ($results | select metadata.namespace metadata.name kind config_maps)

    if ($search_term != null) {
        $view | where config_maps =~ $search_term
    } else {
        $view
    }
}
