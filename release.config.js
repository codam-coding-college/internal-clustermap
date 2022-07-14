module.exports = {
    branches: ['main'],
    plugins: [
      ['@codedependant/semantic-release-docker', {
        dockerTags: ['latest', '{{version}}', '{{major}}-latest', '{{major}}.{{minor}}'],
        dockerImage: 'internal-clustermap',
        dockerFile: 'Dockerfile',
        dockerRegistry: 'ghcr.io',
        dockerProject: 'codam-coding-college',
      }]
    ]
  }
