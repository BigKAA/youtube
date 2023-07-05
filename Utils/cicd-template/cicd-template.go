package main

import (
	"flag"
	"os"
	"text/template"

	"github.com/Masterminds/sprig/v3"
	"gopkg.in/yaml.v3"
)

type CiCdStruct struct {
	Description      string                 `yaml:"description"`
	Image            string                 `yaml:"image"`
	FullnameOverride string                 `yaml:"fullnameOverride"`
	Resources        map[string]interface{} `yaml:"resources"`
	ReadinessProbe   map[string]interface{} `yaml:"readinessProbe"`
	LivenessProbe    map[string]interface{} `yaml:"livenessProbe"`
}

type OutStruct struct {
	Description      string
	Image            string
	FullnameOverride string
	Resources        string
	ReadinessProbe   string
	LivenessProbe    string
}

func main() {
	inputFile := flag.String("in", "", "Data file yaml")
	templateFile := flag.String("template", "", "Template file yaml")
	flag.Parse()

	// Читаем файл с данными
	yamlContent, err := os.ReadFile(*inputFile)
	if err != nil {
		panic(err)
	}
	var cicd CiCdStruct
	err = yaml.Unmarshal(yamlContent, &cicd)
	if err != nil {
		panic(err)
	}

	// Читаем файл шаблона
	templateContenet, err := os.ReadFile(*templateFile)
	if err != nil {
		panic(err)
	}
	template, err := template.New("cicd").Funcs(sprig.FuncMap()).Parse(string(templateContenet))
	if err != nil {
		panic(err)
	}

	description, err := yaml.Marshal(cicd.Description)
	if err != nil {
		panic(err)
	}
	image, err := yaml.Marshal(cicd.Image)
	if err != nil {
		panic(err)
	}
	fullnameOverride, err := yaml.Marshal(cicd.FullnameOverride)
	if err != nil {
		panic(err)
	}
	resources, err := yaml.Marshal(cicd.Resources)
	if err != nil {
		panic(err)
	}
	readnesProbe, err := yaml.Marshal(cicd.ReadinessProbe)
	if err != nil {
		panic(err)
	}
	livenessProbe, err := yaml.Marshal(cicd.LivenessProbe)
	if err != nil {
		panic(err)
	}

	outStruct := OutStruct{
		Description:      string(description),
		Image:            string(image),
		FullnameOverride: string(fullnameOverride),
		Resources:        string(resources),
		ReadinessProbe:   string(readnesProbe),
		LivenessProbe:    string(livenessProbe),
	}

	template.Execute(os.Stdout, outStruct)
	if err != nil {
		panic(err)
	}
}
