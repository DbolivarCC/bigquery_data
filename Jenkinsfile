pipeline {
  agent any

  environment {
    SNOWFLAKE_DATAWAREHOUSE_USER = credentials('SnowflakeDatawarehouseUser')
    SNOWFLAKE_DATAWAREHOUSE_PASSWORD = credentials('SnowflakeDatawarehousePassword')
  }

  stages {
    stage('Checkout and Build Image') {
      steps {
        checkout scm

        sh "docker build -t dbt ."
      }
    }

    stage('Setup dbt profile') {
      steps {
        sh """
          cat > profiles.yml <<EOL
          cc_datawarehouse:
            outputs:
              qa:
                type: snowflake
                threads: 8
                account: lna65058.us-east-1
                user: $SNOWFLAKE_DATAWAREHOUSE_USER
                password: $SNOWFLAKE_DATAWAREHOUSE_PASSWORD
                database: QA_ANALYTICS
                role: TRANSFORMER
                warehouse: TRANSFORMING
                schema: STAGING
                client_session_keep_alive: False
              prod:
                type: snowflake
                threads: 8
                account: lna65058.us-east-1
                user: $SNOWFLAKE_DATAWAREHOUSE_USER
                password: $SNOWFLAKE_DATAWAREHOUSE_PASSWORD
                database: ANALYTICS
                role: TRANSFORMER
                warehouse: TRANSFORMING
                schema: STAGING
                client_session_keep_alive: False
            target: prod
        """

        sh """
          cat > Dockerfile.dbt <<EOL
          FROM dbt
          COPY profiles.yml /root/.dbt/profiles.yml
        """

        sh "docker build -f Dockerfile.dbt -t dbt_run ."
      }
    }

    stage('RUN') {
      steps {
        sh "docker run --rm dbt_run ./jenkins_bin/jenkins_run.sh"
      }
    }
  }

  post {
    always {
      slackSend channel: '#jenkins-alerts', message: "Snowflake Data Warehouse ${currentBuild.displayName}: ${currentBuild.result}"
    }
  }
}
