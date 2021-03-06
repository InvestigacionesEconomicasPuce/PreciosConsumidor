library(readr)
library(ggplot2)
library(gridExtra)
library(plotly)
library(dplyr)
library(tidyverse)

IPC = read_csv("Data/IPChistoricoTrn.csv")
productos = names(IPC)[-1]
IPC = data.frame(IPC)
names(IPC) = c("Fecha", productos)

# Medias Moviles 5 (Centradas)   -------------------------------------------------
MedMovBeta = function(x,n=5){
  #Simulacion de Distribucion Empirica de Ruido -------------------------------------
  set.seed(1)
  #Funcion de Distribucion Empirica de los Datos (Xi)   
  DistribEmpirica = function(Lista_Xi,x=Lista_Xi){
    Lista_Xi = Lista_Xi[!is.na(Lista_Xi)]
    Distrib = c()
    
    for(i in 1:length(x)){
      Indicatriz = as.numeric(Lista_Xi <= x[i])
      Distrib[i] = mean(Indicatriz, na.rm = TRUE)
    }
    
    return(Distrib)
  }
  #Simulacion a Partir de Distribucion Empirica
  rEmpirica = function(Lista_Xi,n=1){
    Lista_Xi = Lista_Xi[!is.na(Lista_Xi)]
    if(n>0){
      u =runif(n)
      xsim=c()
      for(k in 1:n){
        xsim[k] = min(Lista_Xi[u[k]<=DistribEmpirica(Lista_Xi)],na.rm = TRUE)
      }
      
    }else{
      xsim = NA
      print("Ingrese un n adecuado")
    }
    
    return(xsim)
  }
  
  #Extrapolacion de la serie pasada y futura (de datos perdidos por mm12)
  
  
  
  #Algoritmo Medias Moviles
  mvx = stats::filter(x, rep(1 / n, n), sides = 2)
  resx = x - mvx
  
  resxRecup = resx
  resxRecup[is.na(resxRecup)] = rEmpirica(Lista_Xi = resx, n = sum(is.na(resx)))
  
  mvxRecup = x - resxRecup
  
  # par(mfrow = c(2, 1))
  
  # plot(x, main = paste0("IPC, Media Movil [",n,"]"),type = "l", ylab = "IPC")
  # lines(mvxRecup,col= "red")
  # lines(mvx , col = "blue")
  # plot(resxRecup, ylab = "Residuos", main = "Residuos",col="red")
  # lines(resx)
  return(data.frame(x,mvx,resx,mvxRecup,resxRecup))
}

#Media Movil del IPC GENERAL
mav12Gen = MedMovBeta(x = IPC$GENERAL , n = 12 )



#Medir Diferencias entre periodos: -----------------------------------------------
# 2005 - 2006 extra
# 2006 - 2009
# 2009 - 2013
# 2013 - 2017
# 2017 - 2018

# k=2
# periodos = c(2005, 2007, 2010, 2015, 2019)


SerieStnd = as.numeric( IPC[,k+1] / mav12Gen$mvxRecup)


# Serie = mav12Gen$resxRecup
Fecha = as.Date(IPC$Fecha, format = "%d-%m-%y")
Anio = as.numeric(format(Fecha, "%Y"))
# Mes = as.numeric(format(Fecha,"%m"))

etiquetas = c()
for (i in 1:(length(periodos) - 1)) {
  etiquetas[i] = paste0("Periodo: ", periodos[i], " - ", periodos[i + 1])
}


PeriodoCorte = cut(Anio,
                   breaks = periodos ,
                   labels = etiquetas ,
                   right = F)


BDDgraf = data.frame(Fecha, SerieStnd , SerieOrig =  IPC[,k+1], IPC_GeneralS = mav12Gen$mvxRecup , PeriodoCorte)
MediaSeries = BDDgraf %>% group_by(PeriodoCorte) %>% summarise(Media = mean (SerieStnd))

#Graficos Individuales -------------------------------------------
BDDgraf1 = BDDgraf %>%
  select(Fecha,`Serie Original` = SerieOrig, `MM12 (IPC General)` = IPC_GeneralS) %>%
  gather(key = "Serie", value = "value", -Fecha)

seriegraf1 = ggplot(BDDgraf1, aes(x = Fecha, y = value)) + 
  geom_line(aes(color = Serie), size = 0.7) +
  scale_color_manual(values = c("#0174DF","#2E2E2E")) +
  theme_minimal()+
  labs(title = paste("IPC:", productos[k]) , y = "IPC") +
  geom_vline(
    xintercept = as.Date(paste0(periodos[-c(1,length(periodos))],"-01-01")),
    linetype = "dashed",
    color = "red",
    size = 1
  ) +
  theme(
    legend.title = element_text(size = 12, color = "black", face = "bold"),
    legend.justification = c(0, 1),
    legend.position = c(0.05, 0.95),
    legend.background = element_blank(),
    legend.key = element_blank()
  )

# seriegraf1 =  ggplot(data = BDDgraf1, aes(x = Fecha, y = SerieOrig)) +
#   geom_line(size = 0.7) + theme_minimal() +
#   labs(title = paste("IPC:", productos[k]) , y = "IPC")


seriegraf2 =  ggplot(data = BDDgraf, aes(x = Fecha, y = SerieStnd)) +
  geom_line(size = 0.7) + theme_minimal() +
  labs(title = paste("IPC Deflactado:", productos[k]) , y = "IPC Deflactado (por IPC General Suavizado)") +
  geom_vline(
    xintercept = as.Date(paste0(periodos[-c(1,length(periodos))],"-01-01")),
    linetype = "dashed",
    color = "red",
    size = 1
  )


densidades = ggplot(data = BDDgraf ,
                    aes(x = SerieStnd, fill = PeriodoCorte, colour =
                          PeriodoCorte)) +  geom_density(alpha = 0.2) +
  labs(title = paste("IPC Deflactado:", productos[k]), x = "IPC Deflactado por Periodo") +
  geom_vline(data = MediaSeries,
             aes(xintercept = Media, color = PeriodoCorte),
             linetype = "dashed") +
  theme(
    legend.title = element_text(size = 12, color = "black", face = "bold"),
    legend.justification = c(0, 1),
    legend.position = c(0.05, 0.95),
    legend.background = element_blank(),
    legend.key = element_blank()
  )


#Grafico Multiple -----------------
grid.arrange(
  grobs = list(seriegraf1,seriegraf2,densidades),
  widths = c(3, 2),
  layout_matrix = rbind(c(1, 3),
                        c(2, 3))
)

# plot(Grafico)
