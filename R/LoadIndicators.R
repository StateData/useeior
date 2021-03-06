#' Load indicator factors in a list based on model config.
#' @param specs Specifications of the model.
#' @return A list of indicator factors not yet formatted for IOMB.
loadIndicators <- function(specs) {
   logging::loginfo("Initializing model indicators...")
   indicators <- data.frame()
   for (i in specs$Indicators) {
      logging::loginfo(paste("Getting", tolower(i$FullName), "indicators..."))
      if(i$StaticSource) {
         # Load LCIA factors from static file
         StaticIndicatorFactors <- loadLCIAfactors()
         # Subset LCIA factors list for the abbreviations
         factors <- StaticIndicatorFactors[StaticIndicatorFactors$Code == i$Abbreviation, ]
         # Add Indicator column
         factors <- cbind("Indicator" = tolower(gsub(" ", "_", i$FullName)), factors)
      } else {
         func_to_eval <- i$ScriptFunctionCall
         indloadfunction <- as.name(func_to_eval)
         factors <- do.call(eval(indloadfunction), list(i$ScriptFunctionParameters))
         factors <- prepareLCIAmethodforIndicators(factors)
         factors$Code <- i$Abbreviation
      }
      indicators <- rbind(indicators, factors)
   }   
   return(indicators)
}

#' Generating LCIA output formatted for useeiopy using LCIA_indicators static file
#' @param model A complete EEIO model: a list with USEEIO model components and attributes.
#' @return A dataframe of the LCIA factors for all indicators used in the model
generateLCIA <- function (model) {
   # Load LCIA factors
   lciafactors <- loadLCIAfactors()
   # Import LCIA indicators
   lciaindicators <- utils::read.table(system.file("extdata", "USEEIO_LCIA_Indicators.csv", package = "useeior"),
                                       sep = ",", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)
   indicators <- as.vector(unlist(lapply(model$specs$Indicators, FUN = `[[`, "Abbreviation")))
   lciaindicators <- lciaindicators[lciaindicators$Code%in%indicators, ]
   colnames(lciaindicators)[colnames(lciaindicators)=="Unit"] <- "Ref.Unit"
   # Merge LCIA factors and indicators to get meta data
   lcia <- merge(lciafactors, lciaindicators, by = "Code")
   return(lcia)
}

#' Loads all LCIA factors from static source file after melting it to long file
#' @return A dataframe with "Flowable", "UUID", "Context", "Unit", "Amount", "Code".
loadLCIAfactors <- function() {
   # Load static LCIA factors
   lciafact <- utils::read.table(system.file("extdata", "USEEIO_LCIA_Factors.csv", package = "useeior"),
                                 sep = ",", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)
   # Melt these so there is one indicator score per line
   lciafactlong <- reshape2::melt(lciafact, id.vars = c("Flowable", "Context", "Unit", "UUID"))
   # Add Code and Amount
   lciafactlong[, "Code"] <- as.character(lciafactlong$variable)
   lciafactlong[, "Amount"] <- as.numeric(lciafactlong$value)
   # Drop zeroes and keep wanted columns
   lciafactlong <- lciafactlong[lciafactlong$value>0,
                                c("Flowable", "UUID", "Context", "Unit", "Amount", "Code")]
   return(lciafactlong)
}

#' Loads data for all model indicators as listed in model specs
#' @param list a model object with IO data loaded
#' @return list a model object with Indicators added
#' @export
loadandbuildIndicators <- function(model) {
   # Generate C matrix: LCIA indicators
   indicators <- loadIndicators(model$specs)
   # Add flow field
   indicators$Flow <- tolower(apply(indicators[, c("Flowable", "Context", "Unit")],
                                    1, FUN = joinStringswithSlashes))
   # Add to model object
   model$indicators <- indicators
   return(model)
}
