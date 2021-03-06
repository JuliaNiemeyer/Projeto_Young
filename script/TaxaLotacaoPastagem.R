
##Organizar tabelas
library(dplyr)
library(stringr)
library (raster)
library(rgeos)
library(terra)
library(rgdal)
library(tidyverse)

path_outputs_tables <- "./Tabelas_bovinos/output_tabelas/"
dir.create(path_outputs_tables)
path_outputs_maps <- "./Maps"

UF <- c('bahia', 'maranho', 'piau', 'tocantins')

#ler todas as tabelas e fazer o mesmo com todas em um loop

files <- list.files("./Tabelas_bovinos/Censo2017")
names(files) <- c('BA', 'MA', 'PI', 'TO')
UF2 <- c('BA', 'MA', 'PI', 'TO')

for (i in length(files)){
#tables censo2017
tb <- read.csv(paste0("./Tabelas_bovinos/Censo2017/",files[[i]]), sep = ";")

#unique(tb$Nome)
tb %>%
  rename(codigo = `CÃ³digo`)

#reclassificar nomes/caractere
tb$Novo_Nome <-  str_replace_all(tb$Nome, c("`" = "'","Ã´" = "ô","Ãº" = "ú","Ã©" = "é" ,"Ã\u0081" = "Á", "Ã¡" = "á", "Ã³" = "ó", "Ãª" = "ê", "Ã§" = "ç", "Ã£" = "ã", "Ãµ" = "õ", "Ã¢" = "â", "Ã­" = "í" ))
colnames(tb) <- c("codigo", "Nome", "rebanho_Censo2017", "Novo_Nome") 

#Tabelas PPM2020

tb2 <- read.csv(paste0("./Tabelas_bovinos/PPM2020/",UF2[[i]], ".csv"), sep = ";")
tb2$rebanho_PPM2020 <- as.numeric(tb2$rebanho)
tb2 <- tb2[,-2]
colnames(tb2) <- c('municipio', "rebanho_PPM2020")

#retira os espaços antes dos nomes
tb2$municipio <- trimws(tb2$municipio, whitespace = "[\\h\\v\\t ]")

#junta as tabelas baseado no nome dos municipios 
tb3 <- tb %>%
  full_join(tb2, by = c("Novo_Nome" = "municipio"))

write.table(tb3, paste0(path_outputs_tables, UF2[[i]], ".csv"), sep = ",", row.names = F)

}

#Juntar as tabelas em uma única e salvar
tb_all <- list.files(path_outputs_tables, pattern = "csv", full.names = T) 
DF <- do.call('rbind',lapply(tb_all, read.csv, sep = ";"))
write.csv(DF, paste0(path_outputs_tables, "Rebanhos_Mun.csv"))

############# Maps
#ler tif de lulc do bioma e recortar para o matopiba
lulc <- raster("./Maps/mapbiomas-brazil-collection-60-brasil-2020-0000000000-0000000000.tif")
mask <- readOGR(dsn = "./Maps", layer = "Matopiba")

#recortar pra área do Matopiba
lulc_mask <- mask(lulc, mask)
lulc_mask <- crop(lulc_mask, mask)

#reclassificar apenas para pasture (15)
lulc_mask[lulc_mask != 15] <- 0
lulc_mask[lulc_mask == 15] <- 1

#Calcular a área de pasture por municipio
ext <- raster::extract(lulc_mask, mask, sum, na.rm = T)

#write.csv(ext, paste0(path_outputs_tables, Pasture_zonal, ".csv"))


##juntar todas as tabelas no shape dos municipios e exportar
#ler tif shape dos municipios
mato <- readOGR(dsn = "./Maps", layer = "Mun_MATOPIBA")
class(mato$CD_GEOCMU) <- "integer"
mato_df <- as.data.frame(mato)
mato_df$CD_GEOCMU <- as.integer(mato_df$CD_GEOCMU)

#ler a tabela de rebanhos
bois <- read.csv(paste0(path_outputs_tables, "Rebanhos_Mun.csv"))

##Ler tabela de pastagem por municipio (Zonal stats feita no arcgis - ou feia pelo script acima - linha 73)

past <- read.csv(paste0(path_outputs_tables, "Pasture_zonal.csv"), sep = ";")

new.df <- inner_join(mato_df, bois, by = c("CD_GEOCMU" = "codigo"))
new.df <- full_join(new.df, past, by = c("CD_GEOCMU" = "CD_GEOCMU"))

##Exporta a tabela total
write.csv(new.df, paste0(path_outputs_tables, "joined_tables.csv"))

#junta com o shape de municipios e exporta um novo shape com todas as informações
mato_new <- merge(mato, new.df, by = "CD_GEOCMU", duplicateGeoms = T)

writeOGR(mato_new, dsn = path_outputs_maps, layer = "Mun_all_tables", driver = "ESRI Shapefile")

