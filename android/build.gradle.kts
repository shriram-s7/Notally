// Root build file - plugins are declared in settings.gradle.kts

subprojects {
    afterEvaluate {
        project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { android ->
            if (android.namespace == null) {
                android.namespace = "temp.${project.name}"
            }
        }
    }
}
