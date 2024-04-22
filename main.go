package main

import (
    "encoding/json"
	"errors"
    "fmt"
    "io/ioutil"
    "log"
    "net/http"
    "os"
	"strings"
    "github.com/flosch/pongo2/v6"
    "github.com/google/go-jsonnet"
)

type Config struct {
    Templates 		map[string]map[string]string `json:"templates"`
    Clusters 		map[string]Cluster           `json:"clusters"`
    Nodes     		map[string]Node              `json:"nodes"`
	MacAddresses	map[string]string            `json:"macAddresses"`
}

type Cluster struct {
    Nodes []string `json:"nodes"`
	Templates map[string]string `json:"templates"`
	InitrdUrl				string	 		  `json:"initrdUrl"`
	KernelUrl				string	 		  `json:"kernelUrl"`
	InstallRepoUrl			string   		  `json:"installRepoUrl"`
	InstallKickstartUrl		string   		  `json:"installKickstartUrl"`
}

type Node struct {
    MacAddress  			string   		  `json:"macAddress"`
    IgnoreDisks 			[]string 		  `json:"ignoreDisks"`
    Network     			Network  		  `json:"network"`
	Cluster					string   		  `json:"cluster"`
	Templates				map[string]string `json:"templates"`
	InitrdUrl				string	 		  `json:"initrdUrl"`
	KernelUrl				string	 		  `json:"kernelUrl"`
	InstallRepoUrl			string   		  `json:"installRepoUrl"`
	InstallKickstartUrl		string   		  `json:"installKickstartUrl"`
} 

type Network struct {
    Device     string `json:"device"`
    BondSlaves string `json:"bondSlaves"`
}

func joinWithCommaFilter(in *pongo2.Value, param *pongo2.Value) (*pongo2.Value, *pongo2.Error) {
	if !in.CanSlice() {
		return nil, &pongo2.Error{
			Sender:    "filter:random",
			OrigError: errors.New("input is not sliceable"),
		}
	}

    slice := in.Interface().([]interface{})
    strSlice := make([]string, len(slice))

    for i, v := range slice {
        // Convert each element in the slice to a string
        strSlice[i] = pongo2.AsValue(v).String()
    }

    // Join the string slice with a comma
    joined := strings.Join(strSlice, ",")
    return pongo2.AsValue(joined), nil
}

func renderTemplate(w http.ResponseWriter, templateContent string, context pongo2.Context) {
    tpl, err := pongo2.FromString(templateContent)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    err = tpl.ExecuteWriter(context, w)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
}

func fetchTemplate(macAddress string, config Config, templateType string) (string, string) {
	nodeName, ok := config.MacAddresses[macAddress]
	if !ok {
		return "", "MAC not found"
	}
	node, ok := config.Nodes[nodeName]
	if !ok {
		return "", "Node not found"
	}
	cluster := node.Cluster
	if cluster == "" {
		return "", "Cluster not found"
	}
	templateName, ok := config.Clusters[cluster].Templates[templateType]
	if !ok {
		templateName = "default"
	}
	template, ok := config.Templates[templateType][templateName]
	if !ok {
		return "", "Template not found"
	}
	return template, ""
}

func main() {
    // Default file path
    filePath := "default.jsonnet"

    // Check if environment variable is set for the file path
    if val, ok := os.LookupEnv("CONFIG_PATH"); ok {
        filePath = val
    }

	// Read Jsonnet file
    data, err := ioutil.ReadFile(filePath)
    if err != nil {
        fmt.Printf("Error reading file: %v\n", err)
        return
    }

	// Create a Jsonnet VM and evaluate the string
    vm := jsonnet.MakeVM()
    jsonStr, err := vm.EvaluateSnippet(filePath, string(data))
    if err != nil {
        fmt.Printf("Error evaluating Jsonnet: %v\n", err)
        return
    }
    fmt.Println("Generated JSON:")
    fmt.Println(jsonStr)
	
	var config Config
	err = json.Unmarshal([]byte(jsonStr), &config)
	if err != nil {
		fmt.Printf("Error unmarshalling JSON: %v\n", err)
		return
	}

	pongo2.RegisterFilter("join_with_comma", joinWithCommaFilter)
    // fmt.Println("Templates:", config.Templates)
    // fmt.Println("Cluster US1 Nodes:", config.Clusters["us1"].Nodes)
    // fmt.Println("Node 'beastmode.cloud-fortress.net' MAC Address:", config.Nodes["beastmode.cloud-fortress.net"].MacAddress)
    
	http.HandleFunc("/ipxe", func(w http.ResponseWriter, r *http.Request) {
        macAddress := r.URL.Query().Get("mac_address")
        if macAddress == "" {
            http.Error(w, "MAC address is required", http.StatusBadRequest)
            return
        }
		template, err := fetchTemplate(macAddress, config, "ipxe")
		if err != "" {
			http.Error(w, err, http.StatusNotFound)
			return
		}
        renderTemplate(w, template, pongo2.Context{
			"initrdUrl": "http://nas-01.cloud-fortress.net/isos/Rocky-9.3-x86_64-dvd/images/pxeboot/initrd.img",
			"kernelUrl": "http://nas-01.cloud-fortress.net/isos/Rocky-9.3-x86_64-dvd/images/pxeboot/vmlinuz",
			"installRepoUrl": "http://nas-01.cloud-fortress.net/isos/Rocky-9.3-x86_64-dvd",
			"installKickstartUrl": "https://netboot.cloud-fortress.net/kickstart?mac_address${net0/mac}",
		})
    })

    http.HandleFunc("/kickstart", func(w http.ResponseWriter, r *http.Request) {
        macAddress := r.URL.Query().Get("mac_address")
        if macAddress == "" {
            http.Error(w, "MAC address is required", http.StatusBadRequest)
            return
        }
		template, err := fetchTemplate(macAddress, config, "kickstart")
		if err != "" {
			http.Error(w, err, http.StatusNotFound)
			return
		}
        renderTemplate(w, template, pongo2.Context{
			"networkLink": "",
		})
    })

    log.Println("Server is running on http://localhost:8080/")
    http.ListenAndServe(":8080", nil)
}
