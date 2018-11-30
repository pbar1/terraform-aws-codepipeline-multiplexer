package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go/aws"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/codepipeline"
	"github.com/aws/aws-sdk-go/service/ssm"
	"github.com/google/go-github/github"
)

var (
	codePipelineProject = os.Getenv("CODEPIPELINE_PROJECT")
	githubParam         = os.Getenv("GITHUB_SSM_PARAM")

	// ErrNameNotProvided is thrown when a name is not provided
	ErrNameNotProvided = errors.New("no name was provided in the HTTP body")
)

func pipelineExists(target string) bool {
	sess := session.Must(session.NewSession())

	svc := codepipeline.New(sess)

	resp, _ := svc.GetPipeline(&codepipeline.GetPipelineInput{
		Name: &target,
	})
	return resp.Pipeline != nil
}

func clonePipeline(source, target, branch string) error {
	sess := session.Must(session.NewSession())

	svc := codepipeline.New(sess)

	resp, err := svc.GetPipeline(&codepipeline.GetPipelineInput{
		Name: &source,
	})
	if err != nil {
		return err
	}

	newPipelineName := source + target

	pipeline := &codepipeline.PipelineDeclaration{
		Name:          &newPipelineName,
		RoleArn:       resp.Pipeline.RoleArn,
		ArtifactStore: resp.Pipeline.ArtifactStore,
		Stages:        resp.Pipeline.Stages,
	}

	ssmSvc := ssm.New(sess) //keep an eye on this
	ssmRequest := ssm.GetParameterInput{
		Name:           aws.String(githubParam),
		WithDecryption: aws.Bool(true),
	}
	ssmResponse, err := ssmSvc.GetParameter(&ssmRequest)
	if err != nil {
		log.Fatal("Could not retrieve GitHub Token from SSM Parameter Store")
	}
	oauthToken := *ssmResponse.Parameter.Value

	pipeline.Stages[0].Actions[0].Configuration["OAuthToken"] = &oauthToken
	pipeline.Stages[0].Actions[0].Configuration["Branch"] = &branch

	_, err = svc.CreatePipeline(&codepipeline.CreatePipelineInput{
		Pipeline: pipeline,
	})
	return err
}

func destroyPipeline(target string) error {
	sess := session.Must(session.NewSession())

	svc := codepipeline.New(sess)

	_, err := svc.DeletePipeline(&codepipeline.DeletePipelineInput{
		Name: &target,
	})
	return err
}

// Handler is your Lambda function handler
// It uses Amazon API Gateway request/responses provided by the aws-lambda-go/events package,
// However you could use other event sources (S3, Kinesis etc), or JSON-decoded primitive types such as 'string'.
func Handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	// stdout and stderr are sent to AWS CloudWatch Logs
	log.Printf("Processing Lambda request %s\n", request.RequestContext.RequestID)

	// If no name is provided in the HTTP request body, throw an error
	if len(request.Body) < 1 {
		return events.APIGatewayProxyResponse{}, ErrNameNotProvided
	}

	if request.Headers["X-GitHub-Event"] == "pull_request" {
		prEvt := new(github.PullRequestEvent)
		json.Unmarshal([]byte(request.Body), prEvt)
		prName := fmt.Sprintf("pr-%d", *prEvt.PullRequest.Number)
		if *prEvt.PullRequest.State == "open" {
			if !pipelineExists(prName) {
				err := clonePipeline(codePipelineProject, prName, *prEvt.PullRequest.Head.Ref)
				if v, ok := err.(awserr.Error); ok {
					log.Fatalf("failed: %#v %#v\n", v.Message(), v.OrigErr())
				}
			}
		} else if *prEvt.PullRequest.State == "closed" {
			if pipelineExists(prName) {
				err := destroyPipeline(prName)
				if err != nil {
					log.Fatal("The pipeline was too strong! Destroy failed")
				}
			}
		}
	} else {
		log.Fatal("This ain't a pull request!")
	}

	githubDeliveryHeader := make(map[string]string)
	githubDeliveryHeader["X-GitHub-Delivery"] = request.Headers["X-GitHub-Delivery"]

	return events.APIGatewayProxyResponse{
		Headers:    githubDeliveryHeader,
		StatusCode: 200,
	}, nil
}

func main() {
	lambda.Start(Handler)
}
