package main
import (
 "fmt"
 "net/http"
 "os"
)
func handler(w http.ResponseWriter, r *http.Request) {
 h, _ := os.Hostname()
 fmt.Fprintf(w, "Hi there, I'm served from %s!", h)
}
func borat(w http.ResponseWriter, r *http.Request) {
  http.Redirect(w,r , "http://www.croatiaweek.com/wp-content/uploads/2013/04/borat.jpg", 301)
}
func main() {
 http.HandleFunc("/", handler)
 http.HandleFunc("/borat", borat)
 http.ListenAndServe(":8484", nil)
}
