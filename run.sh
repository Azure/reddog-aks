export LOCATION="eastus"

ssh-keygen -f ~/.ssh/aks-reddog -N '' <<< y  

az deployment sub create \
  -f ./deploy/bicep/main.bicep \
  -l $LOCATION \
  -n aks-reddog \
  --parameters prefix="briar" \
  --parameters adminPublicKey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJ2pfj/UHPXlXM5nkW9OBfiqxPcSjQcTvun4Un2qmD90G4DykCWpn+IMzpdeiDS+15i3w0zhHQjeCK9tHRI2N2ywOAqY5sok0aLJy7Da51jqphhQflEu5OpecKYUTeWvlFs2Qeb59UDQ8KikTakkkNgMojq9LfPIgRUrcSOANI6/r3IgT9dQZOz6WJ1SvMR4YkndVlUb6ALTjGd1HJSxmJsMK57C4bG1ubq1cAFK7tjw+M22nJ5s0xZiDrKodG9RG4hQqnKhdr132iQmWgwIaCSRtPwv3gjje16069dAj9MBZauykPny3sCdPMrQa4rRS7nDNSM0u2W4X2D5V5DNjpkcDhRsYNdlhVd8dU0rygJabSLTmuf9Jnmd0+twpfZbWqvnc8nt9YcLBOUaXLC0HB2vBrtenUA/pPOnrZZTdqVDQas6wcW27QtZOVl2Ly/4NEhFolOJ0XviomhbeTozjzJHyJDDA/PPbfXQDeVRj1SjoJnZ/NCfC1kiNQRKMhwk0= brianredmond@Brians-SpaceGrey-Mac.local"
  #--parameters adminPublicKey="~/.ssh/aks-reddog.pub"