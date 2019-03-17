require 'base64'
require 'json'
require 'rspec'
require 'rack/test'
require_relative '../mutating_webhook'

# Expose the app to rack-test
def app
  Sinatra::Application
end

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

def test_uid
  'test-1234'
end

def test_admission_review
  {
    'kind' => 'AdmissionReview',
    'apiVersion' => 'admission.k8s.io/v1beta1',
    'request' => {
      'uid' => test_uid,
      'kind' => {
        'group' => '',
        'version' => 'v1',
        'kind' => 'Pod'
      },
      'resource' => {
        'group' => '',
        'version' => 'v1',
        'resource' => 'pods'
      },
      'namespace' => 'test',
      'operation' => 'CREATE',
      'object' => {
        'metadata' => {
          'name' => 'test-pod',
          'namespace' => 'test'
        },
        'spec' => {
          'volumes' => [
            {
              'name' => 'default-token-vks5v',
              'secret' => {
                'secretName' => 'default-token-vks5v'
              }
            }
          ],
          'containers' => [
            {
              'name' => 'app',
              'image' => 'k8s.gcr.io/pause',
              'resources' => {

              },
              'volumeMounts' => [
                {
                  'name' => 'default-token-vks5v',
                  'readOnly' => true,
                  'mountPath' => '/var/run/secrets/kubernetes.io/serviceaccount'
                }
              ],
              'terminationMessagePath' => '/dev/termination-log',
              'terminationMessagePolicy' => 'File',
              'imagePullPolicy' => 'Always'
            }
          ],
          'restartPolicy' => 'Always',
          'terminationGracePeriodSeconds' => 30,
          'dnsPolicy' => 'ClusterFirst',
          'serviceAccountName' => 'default',
          'serviceAccount' => 'default',
          'securityContext' => {

          },
          'schedulerName' => 'default-scheduler',
          'tolerations' => [
            {
              'key' => 'node.kubernetes.io/not-ready',
              'operator' => 'Exists',
              'effect' => 'NoExecute',
              'tolerationSeconds' => 300
            },
            {
              'key' => 'node.kubernetes.io/unreachable',
              'operator' => 'Exists',
              'effect' => 'NoExecute',
              'tolerationSeconds' => 300
            }
          ],
          'priority' => 0,
          'enableServiceLinks' => true
        },
        'status' => {

        }
      },
      'oldObject' => nil,
      'dryRun' => false
    }
  }
end
